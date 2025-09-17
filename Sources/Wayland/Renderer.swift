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

    mutating func draw(block: some Block) {
        if let orientation = block as? OrientationBlock {
            let chagned = self.orientation != orientation.orientation
            if chagned {
                self.orientation = orientation.orientation
                pushLayer(self.orientation)
            }
            draw(block: block.layer)
            if chagned {
                popLayer()
            }
        } else if let word = block as? Word {
            consume(word: word)
        } else if let group = block as? BlockGroup {
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
        } else {
            draw(block: block.layer)
        }
    }

    mutating func draw(any: any Block) {
        draw(block: any)
    }

    private mutating func pushLayer(_ o: Orientation) {
        let x: UInt = layers[layers.count - 1].startX
        let y: UInt = layers[layers.count - 1].startY
        let h: UInt = layers[layers.count - 1].height
        let w: UInt = layers[layers.count - 1].width
        switch o {
        case .horizontal:
            layers.append(Consumed(startX: x + w, startY: y, orientation: o))
        case .vertical:
            layers.append(Consumed(startX: x, startY: y + h, orientation: o))
        }
    }

    private mutating func popLayer() {
        _ = layers.popLast()
    }

    private mutating func consume(word: Word) {
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

struct Consumed {
    let startX: UInt
    let startY: UInt
    let orientation: Orientation
    var width: UInt = 0
    var height: UInt = 0
}
