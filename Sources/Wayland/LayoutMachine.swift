import Logging

@MainActor
public protocol Renderer {
  static func drawQuad(_ quad: Quad)
  static func drawText(_ text: Text)
}

@MainActor
public struct LayoutMachine: ~Copyable {

  public init(
    _ drawer: any Renderer.Type,
    _ logLevel: Logger.Level
  ) {
    self.logger = Logger.create(logLevel: logLevel)
    self.drawer = drawer
    self.orientation = .vertical
    self.layers = [Consumed(startX: 0, startY: 0, orientation: self.orientation)]
    selected = 0
    current = 0
  }
  let drawer: Renderer.Type
  let logger: Logger
  var orientation: Orientation
  var layers: [Consumed]
  var selected: Hash
  var current: Hash

  var currentSelected: Bool {
    selected == current
  }

  public mutating func reset() {
    self.orientation = .vertical
    self.layers = [Consumed(startX: 0, startY: 0, orientation: self.orientation)]
    current = 0
  }

  mutating func selct(hashing string: String) {
    let prev = self.selected
    let h = hash(string)
    let hash = hash(prev ^ h)  // Not sure what operation to do here.
    self.selected = hash
    logger.notice("Selection set: \(hash), was: \(prev)")
  }

  mutating func current(hashing string: String) {
    let prev = self.current
    let h = hash(string)
    let hash = hash(prev ^ h)  // Not sure what operation to do here.
    self.current = hash
    logger.notice("Hashing: \(string), Current set: \(hash), was: \(prev)")
  }

  mutating func pushLayer(_ o: Orientation) {
    let x: UInt = layers[layers.count - 1].startX
    let y: UInt = layers[layers.count - 1].startY
    let h: UInt = layers[layers.count - 1].height
    let w: UInt = layers[layers.count - 1].width
    let c =
      switch o {
      case .horizontal:
        Consumed(startX: x + w, startY: y, orientation: o)
      case .vertical:
        Consumed(startX: x, startY: y + h, orientation: o)
      }
    layers.append(c)
  }

  mutating func popLayer() {
    _ = layers.popLast()
  }

  mutating func consume(rect: Rect, selected: Bool) {
    let x: UInt = layers[layers.count - 1].startX
    let y: UInt = layers[layers.count - 1].startY
    let h: UInt = layers[layers.count - 1].height
    let w: UInt = layers[layers.count - 1].width
    let o: Orientation = layers[layers.count - 1].orientation
    let quadH: UInt = rect.height * rect.scale
    let quadW: UInt = rect.width * rect.scale
    let color: Color
    if selected {
      color = .cyan
    } else {
      color = rect.color
    }
    let quad = Quad(
      dst_p0: (y + h, x + w),
      dst_p1: (y + h + quadH, x + w + quadW),
      tex_tl: (0, 0), tex_br: (1, 1), color: color)
    switch o {
    case .horizontal:
      layers[layers.count - 1].height = max(layers[layers.count - 1].height, quadH)
      layers[layers.count - 1].width += quadW + rect.scale
    case .vertical:
      layers[layers.count - 1].height += quadH + rect.scale
      layers[layers.count - 1].width = max(layers[layers.count - 1].width, quadW)
    }
    drawer.drawQuad(quad)
  }

  mutating func consume(word: Word, selected: Bool) {
    let x: UInt = layers[layers.count - 1].startX
    let y: UInt = layers[layers.count - 1].startY
    let h: UInt = layers[layers.count - 1].height
    let w: UInt = layers[layers.count - 1].width
    let o: Orientation = layers[layers.count - 1].orientation
    var text: Text
    switch o {
    case .horizontal:
      text = word.draw(at: (y: y, x: x + w))
      layers[layers.count - 1].height = max(layers[layers.count - 1].height, word.height)
      layers[layers.count - 1].width += word.width + word.scale
    case .vertical:
      text = word.draw(at: (y: y + h, x: x))
      layers[layers.count - 1].height += word.height + word.scale
      layers[layers.count - 1].width = max(layers[layers.count - 1].width, word.width)
    }
    if selected {
      text.background = .cyan
    }
    drawer.drawText(text)
  }
}

struct Consumed: Equatable {
  let startX: UInt
  let startY: UInt
  let orientation: Orientation
  var width: UInt = 0
  var height: UInt = 0
}
