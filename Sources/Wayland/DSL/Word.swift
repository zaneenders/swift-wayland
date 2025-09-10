public struct Word: Block {
    let label: String
    var v: VLayout = .center
    var h: HLayout = .center
    var scale: Float = Wayland.scale
    public init(_ text: String) {
        self.label = text
    }

    public func scale(_ scale: Float = 2.0) -> Self {
        var copy = self
        copy.scale = scale
        return copy
    }
    var width: Float {
        // (size of the charaters) * (number of space) - (trailing space)
        (Float(label.count) * Float(Wayland.glyphW) * self.scale) + (Float(label.count) * self.scale) - self.scale
    }
    var height: Float {
        Float(Wayland.glyphH) * self.scale
    }

    func render(at: (y: UInt32, x: UInt32)) -> Text {
        let penX = (Float(at.x) / 2) - (self.width / 2)
        let penY = (Float(at.y) / 2) - (self.height / 2)
        return Text(label, at: (Float(at.x), Float(at.y)), scale: self.scale, color: Color.white)
    }
}

enum VLayout {
    case center
}
enum HLayout {
    case center
}
