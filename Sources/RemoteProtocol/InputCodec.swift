import Chroma
import NIOCore

extension ByteBuffer {
  mutating func writeInputCommand(_ command: Command) throws {
    switch command {
    case .navigation(let value):
      writeInteger(UInt8(1)); writeInteger(value.wireValue)
    case .action(let value):
      writeInteger(UInt8(2)); writeInteger(value.wireValue)
    case .editing(let value):
      writeInteger(UInt8(3)); try writeTextEvent(value)
    case .application(let id):
      writeInteger(UInt8(4)); try writeWireString(id.rawValue)
    }
  }

  mutating func readInputCommand() throws -> Command {
    switch try readWire(UInt8.self) {
    case 1:
      guard let value = NavigationCommand(wireValue: try readWire(UInt8.self)) else { throw RemoteProtocolError.malformedMessage }
      return .navigation(value)
    case 2:
      guard let value = ActionCommand(wireValue: try readWire(UInt8.self)) else { throw RemoteProtocolError.malformedMessage }
      return .action(value)
    case 3: return .editing(try readTextEvent())
    case 4: return .application(CommandID(try readWireString()))
    default: throw RemoteProtocolError.malformedMessage
    }
  }

  mutating func writeTextEvent(_ event: TextEditEvent) throws {
    switch event {
    case .insert(let text): writeInteger(UInt8(0)); try writeWireString(text)
    case .backspace: writeInteger(UInt8(1))
    case .deleteForward: writeInteger(UInt8(2))
    case .moveCaretLeft: writeInteger(UInt8(3))
    case .moveCaretRight: writeInteger(UInt8(4))
    case .moveCaretUp: writeInteger(UInt8(5))
    case .moveCaretDown: writeInteger(UInt8(6))
    case .selectCaretUp: writeInteger(UInt8(7))
    case .selectCaretDown: writeInteger(UInt8(8))
    case .moveCaretToStart: writeInteger(UInt8(9))
    case .moveCaretToEnd: writeInteger(UInt8(10))
    case .selectAll: writeInteger(UInt8(11))
    case .copy: writeInteger(UInt8(12))
    case .cut: writeInteger(UInt8(13))
    case .paste: writeInteger(UInt8(14))
    case .submit: writeInteger(UInt8(15))
    case .endEditing: writeInteger(UInt8(16))
    }
  }

  mutating func readTextEvent() throws -> TextEditEvent {
    switch try readWire(UInt8.self) {
    case 0: return .insert(try readWireString())
    case 1: return .backspace
    case 2: return .deleteForward
    case 3: return .moveCaretLeft
    case 4: return .moveCaretRight
    case 5: return .moveCaretUp
    case 6: return .moveCaretDown
    case 7: return .selectCaretUp
    case 8: return .selectCaretDown
    case 9: return .moveCaretToStart
    case 10: return .moveCaretToEnd
    case 11: return .selectAll
    case 12: return .copy
    case 13: return .cut
    case 14: return .paste
    case 15: return .submit
    case 16: return .endEditing
    default: throw RemoteProtocolError.malformedMessage
    }
  }

  private mutating func writeWireString(_ value: String) throws {
    let bytes = Array(value.utf8)
    guard bytes.count <= Int(UInt32.max) else { throw RemoteProtocolError.stringTooLarge(bytes.count) }
    writeInteger(UInt32(bytes.count), endianness: .little); writeBytes(bytes)
  }
  private mutating func readWireString() throws -> String {
    let count = Int(try readWire(UInt32.self))
    guard count <= RemoteWire.maximumPayloadBytes, let value = readString(length: count) else { throw RemoteProtocolError.malformedMessage }
    return value
  }
  private mutating func readWire<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
    guard let value: T = readInteger(endianness: .little) else { throw RemoteProtocolError.malformedMessage }
    return value
  }
}

extension NavigationCommand {
  fileprivate var wireValue: UInt8 {
    switch self {
    case .up: 0; case .down: 1; case .left: 2; case .right: 3; case .in: 4; case .out: 5
    case .next: 6; case .previous: 7; case .pageUp: 8; case .pageDown: 9; case .home: 10; case .end: 11
    }
  }
  fileprivate init?(wireValue: UInt8) {
    switch wireValue {
    case 0: self = .up; case 1: self = .down; case 2: self = .left; case 3: self = .right
    case 4: self = .in; case 5: self = .out; case 6: self = .next; case 7: self = .previous
    case 8: self = .pageUp; case 9: self = .pageDown; case 10: self = .home; case 11: self = .end
    default: return nil
    }
  }
}

extension ActionCommand {
  fileprivate var wireValue: UInt8 {
    switch self { case .activate: 0; case .submit: 1; case .cancel: 2; case .dismiss: 3 }
  }
  fileprivate init?(wireValue: UInt8) {
    switch wireValue { case 0: self = .activate; case 1: self = .submit; case 2: self = .cancel; case 3: self = .dismiss; default: return nil }
  }
}
