import ShapeTree

extension Text {
  /// Draw method for Wayland rendering - this is the only Wayland-specific method needed
  func draw(at: (y: UInt, x: UInt), scale: UInt = 1, foreground: Color = .white, background: Color = .black)
    -> RenderableText
  {
    return RenderableText(
      label, at: (x: at.x, y: at.y),
      scale: scale,
      foreground: foreground,
      background: background)
  }
}
