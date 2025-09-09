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
    public static var random: Color {
        let allColors: [Color] = [
            .white, .black, .teal, .blue, .green,
            .orange, .yellow, .red, .purple, .pink,
            .brown, .gray, .cyan, .magenta,
        ]
        return allColors.randomElement()!
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
    public static var blue: Color {
        Color(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
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
    public static var purple: Color {
        Color(r: 0.5, g: 0.0, b: 0.5, a: 1.0)
    }
    public static var pink: Color {
        Color(r: 0.9, g: 0.5, b: 0.6, a: 1.0)
    }
    public static var brown: Color {
        Color(r: 0.4, g: 0.25, b: 0.1, a: 1.0)
    }
    public static var gray: Color {
        Color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
    }
    public static var cyan: Color {
        Color(r: 0.0, g: 1.0, b: 1.0, a: 1.0)
    }
    public static var magenta: Color {
        Color(r: 1.0, g: 0.0, b: 1.0, a: 1.0)
    }
}
