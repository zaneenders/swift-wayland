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
    var layers: [Consumed] = []
    var up: Bool = false

    mutating func draw(block: some Block) {
        if let rect = block as? Solid {
            consume(quad: rect.quad)
        } else if let word = block as? Word {
            consume(word: word)
        } else if let group = block as? BlockGroup {
            pushLayer()
            /*
            let count = group.children.count
            let block = group.children[count / 2]
            draw(any: block)
            */
            for block in group.children {
                draw(block: block)
            }
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
        let h = layers[layers.count - 1].height
        let w = layers[layers.count - 1].width
        let text = word.render(at: (y: h, x: w))
        _drawText(text)
        consume(height: word.height)
        consume(width: word.width)
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
