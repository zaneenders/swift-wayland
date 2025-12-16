public struct Text {
    public let text: String
    public let pos: (x: UInt, y: UInt)
    public let scale: UInt
    public let color: Color
    public init(
        _ text: String, at pos: (x: UInt, y: UInt), scale: UInt, color: Color = .white
    ) {
        self.text = text
        self.pos = pos
        self.scale = scale
        self.color = color
    }
}
