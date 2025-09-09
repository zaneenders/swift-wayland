struct Text {
    let text: String
    let pos: (x: Float, y: Float)
    let scale: Float
    let color: Color
    init(
        _ text: String, at pos: (x: Float, y: Float), scale: Float, color: Color = Color(r: 1, g: 1, b: 1, a: 1)
    ) {
        self.text = text
        self.pos = pos
        self.scale = scale
        self.color = color
    }
}
