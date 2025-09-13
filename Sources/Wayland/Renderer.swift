@MainActor
struct Renderer: ~Copyable {

    init(
        _ dim: (height: UInt, width: UInt),
        _ drawQuad: @escaping (Quad) -> Void,
        _ drawText: @escaping (Text) -> Void
    ) {
        self.height = dim.height
        self.width = dim.width
        self._drawQuad = drawQuad
        self._drawText = drawText
    }

    let _drawQuad: (Quad) -> Void
    let _drawText: (Text) -> Void
    let height: UInt
    let width: UInt
    var layers: [Consumed] = [Consumed()]
    var up: Bool = false
    var orientation: Orientation = .vertical

    mutating func draw(block: some Block) {
        if let rect = block as? Solid {
            consume(quad: rect.quad)
        } else if let orientation = block as? OrientationBlock {
            self.orientation = orientation.orientation
            draw(block: block.layer)
        } else if let word = block as? Word {
            consume(word: word)
        } else if let group = block as? BlockGroup {
            pushLayer()
            for block in group.children {
                draw(block: block)
            }
            #if FrameInfo
            switch orientation {
            case .vertical:
                let w = layers[layers.count - 1].width
                _drawQuad(
                    Quad(
                        dst_p0: (w - 1, 0),
                        dst_p1: (w + 1, height),
                        color: Color.red))
            case .horizontal:
                let h = layers[layers.count - 1].height
                _drawQuad(
                    Quad(
                        dst_p0: (0, h - 1),
                        dst_p1: (width, h + 1),
                        color: Color.red))
            }
            #endif
            popLayer()
        } else {
            draw(block: block.layer)
        }
    }

    mutating func draw(any: any Block) {
        draw(block: any)
    }

    private mutating func pushLayer() {
        layers.append(Consumed())
        up = false
    }

    private mutating func popLayer() {
        _ = layers.popLast()
        up = true
    }

    private mutating func consume(height: UInt) {
        layers[layers.count - 1].height += height
    }

    private mutating func consume(width: UInt) {
        layers[layers.count - 1].width += width
    }

    private mutating func consume(word: Word) {
        let h: UInt
        let w: UInt
        switch orientation {
        case .horizontal:
            h = 0
            w = layers[layers.count - 1].width
            layers[layers.count - 1].height = max(layers[layers.count - 1].height, word.height)
            consume(width: word.width + Wayland.scale)
        case .vertical:
            w = 0
            h = layers[layers.count - 1].height
            layers[layers.count - 1].width = max(layers[layers.count - 1].width, word.width)
            consume(height: word.height + Wayland.scale)
        }
        let text = word.render(at: (y: h, x: w))
        _drawText(text)
    }

    private mutating func consume(quad: Quad) {
        _drawQuad(quad)
        consume(height: quad.height)
        consume(width: quad.width)
    }
}

struct Consumed {
    var height: UInt = 0
    var width: UInt = 0
}
