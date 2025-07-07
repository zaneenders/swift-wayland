import NIOCore
import NIOPosix

struct WaylandMessage {
    let object: UInt32
    let length: UInt16
    let opcode: UInt16
    let message: ByteBuffer?
}

final class WaylandMessageCoder: ByteToMessageDecoder, MessageToByteEncoder {
    typealias InboundOut = WaylandMessage
    typealias OutboundIn = WaylandMessage

    func decode(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer
    ) throws -> DecodingState {
        guard buffer.readableBytes >= 8 else {
            return .needMoreData
        }
        let objectId = buffer.readInteger(endianness: .little, as: UInt32.self)!
        let opcode = buffer.readInteger(endianness: .little, as: UInt16.self)!
        let length = buffer.readInteger(endianness: .little, as: UInt16.self)!
        let message_bites_remaining: Int = roundup4(Int(length)) - 8
        guard buffer.readableBytes >= message_bites_remaining else {
            buffer.moveReaderIndex(to: buffer.readerIndex - 8)
            return .needMoreData
        }
        var message: ByteBuffer? = nil
        if message_bites_remaining > 0 {
            message = buffer.readSlice(length: message_bites_remaining)
        }
        let event = WaylandMessage(object: objectId, length: length, opcode: opcode, message: message)
        context.fireChannelRead(Self.wrapInboundOut(event))
        return .continue
    }

    func encode(data: WaylandMessage, out: inout ByteBuffer) throws {
        out.writeInteger(data.object, endianness: .little, as: UInt32.self)
        out.writeInteger(data.opcode, endianness: .little, as: UInt16.self)
        out.writeInteger(data.length, endianness: .little, as: UInt16.self)
        if var message = data.message {
            out.writeBuffer(&message)
        }
    }
}
