@MainActor
struct Renderer: ~Copyable {
  init(
    _ dim: (height: UInt, width: UInt),
    _ drawQuad: @escaping (Quad, borrowing Self) -> Void,
    _ drawText: @escaping (Text, borrowing Self) -> Void
  ) {
    self.height = dim.height
    self.width = dim.width
    self._drawQuad = drawQuad
    self._drawText = drawText
    self.orientation = .vertical
    self.layers = [Consumed(startX: 0, startY: 0, orientation: self.orientation)]
  }

  let _drawQuad: (Quad, borrowing Self) -> Void
  let _drawText: (Text, borrowing Self) -> Void
  let height: UInt
  let width: UInt
  var orientation: Orientation
  var layers: [Consumed]

  func frameInfo() {
    #if FrameInfo
    switch orientation {
    case .vertical:
      let w = layers[layers.count - 1].width
      _drawQuad(
        Quad(
          dst_p0: (w - 1, 0),
          dst_p1: (w + 1, height),
          color: Color.red), self)
    case .horizontal:
      let h = layers[layers.count - 1].height
      _drawQuad(
        Quad(
          dst_p0: (0, h - 1),
          dst_p1: (width, h + 1),
          color: Color.red), self)
    }
    #endif
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

  mutating func consume(rect: Rect) {
    let x: UInt = layers[layers.count - 1].startX
    let y: UInt = layers[layers.count - 1].startY
    let h: UInt = layers[layers.count - 1].height
    let w: UInt = layers[layers.count - 1].width
    let o: Orientation = layers[layers.count - 1].orientation
    let quadH: UInt = rect.height * rect.scale
    let quadW: UInt = rect.width * rect.scale
    let quad = Quad(
      dst_p0: (y + h, x + w),
      dst_p1: (y + h + quadH, x + w + quadW),
      tex_tl: (0, 0), tex_br: (1, 1), color: rect.color)
    switch o {
    case .horizontal:
      layers[layers.count - 1].height = max(layers[layers.count - 1].height, quadH)
      layers[layers.count - 1].width += quadW + rect.scale
    case .vertical:
      layers[layers.count - 1].height += quadH + rect.scale
      layers[layers.count - 1].width = max(layers[layers.count - 1].width, quadW)
    }
    _drawQuad(quad, self)
  }

  mutating func consume(word: Word) {
    let x: UInt = layers[layers.count - 1].startX
    let y: UInt = layers[layers.count - 1].startY
    let h: UInt = layers[layers.count - 1].height
    let w: UInt = layers[layers.count - 1].width
    let o: Orientation = layers[layers.count - 1].orientation
    let text: Text
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
    _drawText(text, self)
  }
}

struct Consumed: Equatable {
  let startX: UInt
  let startY: UInt
  let orientation: Orientation
  var width: UInt = 0
  var height: UInt = 0
}
