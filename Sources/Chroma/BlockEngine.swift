@MainActor
public enum BlockEngine {
  // Resolve a composite once per stack operation. Reusing the primitive for
  // measurement, expansion and drawing avoids rebuilding application bodies.
  // This is deliberately not retained across frames or input events.
  static func resolve(_ block: any Block) -> any PrimitiveBlock {
    if let primitive = block as? any PrimitiveBlock { return primitive }
    return resolve(block.body)
  }

  public static func measure(
    _ block: any Block,
    proposal: Size,
    context: RenderContext
  ) -> Size {
    func open<B: Block>(_ block: B) -> Size {
      if let primitive = block as? any PrimitiveBlock {
        return primitive.sizeThatFits(proposal, context: context)
      }
      return measure(block.body, proposal: proposal, context: context)
    }
    return open(block)
  }

  public static func draw(
    _ block: any Block,
    into drawList: inout DrawList,
    in rect: Rect,
    context: RenderContext
  ) {
    func open<B: Block>(_ block: B) {
      if let primitive = block as? any PrimitiveBlock {
        primitive.draw(into: &drawList, in: rect, context: context)
      } else {
        draw(block.body, into: &drawList, in: rect, context: context)
      }
    }
    open(block)
  }

  public static func expandsHorizontally(_ block: any Block) -> Bool {
    func open<B: Block>(_ block: B) -> Bool {
      if let primitive = block as? any PrimitiveBlock {
        return primitive.expandsHorizontally
      }
      return expandsHorizontally(block.body)
    }
    return open(block)
  }

  public static func expandsVertically(_ block: any Block) -> Bool {
    func open<B: Block>(_ block: B) -> Bool {
      if let primitive = block as? any PrimitiveBlock {
        return primitive.expandsVertically
      }
      return expandsVertically(block.body)
    }
    return open(block)
  }
}
