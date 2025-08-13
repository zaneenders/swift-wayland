import NIOCore
import NIOPosix

struct WaylandMessage {
    static let headerSize: UInt16 = 8
    let object: UInt32
    let length: UInt16
    let opcode: UInt16
    let message: ByteBuffer?
    let fd: Int?  // File Descriptor

    init(object: UInt32, opcode: UInt16) {
        self.object = object
        self.opcode = opcode
        self.length = Self.headerSize
        self.message = nil
        self.fd = nil
    }

    init(object: UInt32, opcode: UInt16, message: ByteBuffer) {
        self.object = object
        assert(message.readableBytes < UInt16.max)
        self.length = Self.headerSize + UInt16(message.readableBytes)
        self.opcode = opcode
        self.message = message
        self.fd = nil
    }

    init(object: UInt32, opcode: UInt16, message: ByteBuffer, fd: Int) {
        self.object = object
        assert(message.readableBytes < UInt16.max)
        self.length = Self.headerSize + UInt16(message.readableBytes)
        self.opcode = opcode
        self.message = message
        self.fd = fd
    }
}

final class WaylandMessageDecoder: ByteToMessageDecoder {
    typealias InboundOut = WaylandMessage

    func decode(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer
    ) throws -> DecodingState {
        guard buffer.readableBytes >= WaylandMessage.headerSize else {
            return .needMoreData
        }
        let objectId = buffer.readInteger(endianness: .little, as: UInt32.self)!
        let opcode = buffer.readInteger(endianness: .little, as: UInt16.self)!
        let length = buffer.readInteger(endianness: .little, as: UInt16.self)!
        let message_bites_remaining: Int = roundup4(Int(length)) - Int(WaylandMessage.headerSize)
        guard buffer.readableBytes >= message_bites_remaining else {
            buffer.moveReaderIndex(to: buffer.readerIndex - Int(WaylandMessage.headerSize))
            return .needMoreData
        }
        var message: ByteBuffer? = nil
        if message_bites_remaining > 0 {
            message = buffer.readSlice(length: message_bites_remaining)
            let event = WaylandMessage(object: objectId, opcode: opcode, message: message!)
            context.fireChannelRead(Self.wrapInboundOut(event))
        } else {
            let event = WaylandMessage(object: objectId, opcode: opcode)
            context.fireChannelRead(Self.wrapInboundOut(event))
        }
        return .continue
    }
}

final class WaylandMessageEncoder: ChannelOutboundHandler {
    public typealias OutboundIn = WaylandMessage
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let message = Self.unwrapOutboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: Int(message.length))
        buffer.writeInteger(message.object, endianness: .little, as: UInt32.self)
        buffer.writeInteger(message.opcode, endianness: .little, as: UInt16.self)
        buffer.writeInteger(message.length, endianness: .little, as: UInt16.self)
        if var contents = message.message {
            buffer.writeBuffer(&contents)
        }

        var envelop = AddressedEnvelope(remoteAddress: context.channel.remoteAddress!, data: buffer)

        if let fd = message.fd {
            // TODO: unerstand ecnState
            envelop.metadata = AddressedEnvelope<ByteBuffer>.Metadata(ecnState: .transportCapableFlag0, fd: fd)
        }
        context.write(
            Self.wrapOutboundOut(envelop),
            promise: promise
        )
    }
}

// TODO: This should be fileprivate
internal func roundup4(_ value: Int) -> Int {
    return (value + 3) & ~3
}

// TODO: This should be fileprivate
extension String {
    internal func getRounded() -> String {
        let padding = roundup4(self.count) - self.count
        var copy = self
        for _ in 0..<padding {
            copy.append("\0")
        }
        return copy
    }
}
