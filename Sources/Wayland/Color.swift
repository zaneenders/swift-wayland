public struct Color: BitwiseCopyable {

    public var r, g, b, a: Float

    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

extension Color {
    public static var white: Color {
        Color(r: 1, g: 1, b: 1, a: 1)
    }
    public static var black: Color {
        Color(r: 0, g: 0, b: 0, a: 1)
    }
    public static var teal: Color {
        Color(r: 0, g: 1, b: 1, a: 1)
    }
    public static var green: Color {
        Color(r: 0.5, g: 1, b: 0.5, a: 1)
    }
    public static var orange: Color {
        Color(r: 1, g: 0.5, b: 0, a: 1)
    }
    public static var yellow: Color {
        Color(r: 1.0, g: 1.0, b: 0.0, a: 1.0)
    }
    public static var red: Color {
        Color(r: 1, g: 0, b: 0, a: 1)
    }
}
