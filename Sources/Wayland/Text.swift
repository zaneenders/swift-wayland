public struct Text {
    public let text: String
    public let pos: (x: Float, y: Float)
    public let scale: Float
    public let color: Color
    public init(
        _ text: String, at pos: (x: Float, y: Float), scale: Float, color: Color = .white
    ) {
        self.text = text
        self.pos = pos
        self.scale = scale
        self.color = color
    }
}
