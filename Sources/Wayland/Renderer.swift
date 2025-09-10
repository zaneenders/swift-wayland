@MainActor
struct Renderer: ~Copyable {

    init(
        _ dim: (height: UInt32, width: UInt32),
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
    let height: UInt32
    let width: UInt32
    var layers: [Consumed] = []
    var up: Bool = false

    mutating func draw(block: some Block) {
        if let rect = block as? Solid {
            consume(quad: rect.quad)
        } else if let word = block as? Word {
            consume(word: word)
        } else if let group = block as? BlockGroup {
            pushLayer()
            for block in group.children {
                draw(block: block)
            }
            popLayer()
        } else {
            draw(block: block.layer)
        }
    }

    private mutating func pushLayer() {
        layers.append(Consumed())
        up = false
    }

    private mutating func popLayer() {
        _ = layers.popLast()
        up = true
    }

    private mutating func consume(height: UInt32) {
        layers[layers.count - 1].height += Int(height)
    }

    private mutating func consume(width: UInt32) {
        layers[layers.count - 1].width += Int(width)
    }

    private mutating func consume(word: Word) {
        let h = layers[layers.count - 1].height
        let w = layers[layers.count - 1].width
        _drawText(
            word.render(
                at: (
                    y: UInt32(h),
                    x: UInt32(width / 2) - UInt32(word.width / 2)
                )
            ))
        consume(height: UInt32(word.height))
        consume(width: UInt32(word.width))
    }

    private mutating func consume(quad: Quad) {
        consume(height: UInt32(quad.height))
        consume(width: UInt32(quad.width))
        _drawQuad(quad)
    }
}

struct Consumed {
    var height = 0
    var width = 0
}
