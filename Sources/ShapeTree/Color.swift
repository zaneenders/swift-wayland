extension Color {
  private static let allColors: [Color] = [
    .white, .black, .teal, .blue, .green,
    .orange, .yellow, .red, .purple, .pink,
    .brown, .gray, .cyan, .magenta,
  ]
  public static var random: Color {
    return allColors.randomElement()!
  }
}

public enum Color: Sendable {
  case white
  case black
  case teal
  case blue
  case green
  case orange
  case yellow
  case red
  case purple
  case pink
  case brown
  case gray
  case cyan
  case magenta
}
