/// Displays an RGBA8 image at its intrinsic pixel size by default.
///
/// `scaling` controls how pixels are drawn when a parent or a `sizing` modifier
/// assigns a rectangle with a different aspect ratio. `.contain` letterboxes,
/// `.cover` crops to fill, and `.stretch` distorts to fill. Images do not claim
/// extra stack space unless expansion is explicitly requested with `.sizing`.
public struct Image: PrimitiveBlock {
  public var resource: ImageResource
  public var scaling: ImageScaling
  public var alignment: ImageAlignment

  public init(
    _ resource: ImageResource,
    scaling: ImageScaling = .contain,
    alignment: ImageAlignment = .center
  ) {
    self.resource = resource
    self.scaling = scaling
    self.alignment = alignment
  }

  public func sizeThatFits(_ proposal: Size, context: RenderContext) -> Size {
    resource.size
  }

  public var expandsHorizontally: Bool { false }
  public var expandsVertically: Bool { false }

  public func draw(into drawList: inout DrawList, in rect: Rect, context: RenderContext) {
    drawList.image(resource, in: rect, scaling: scaling, alignment: alignment)
  }
}
