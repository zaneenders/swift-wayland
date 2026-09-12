/// Evaluates its builder during layout and drawing rather than at installation time.
/// Use this at a renderer's root to track observable reads in root-level content.
public struct DeferredBlock<Content: Block>: Block {
  private let content: @MainActor () -> Content

  public init(@BlockBuilder content: @escaping @MainActor () -> Content) {
    self.content = content
  }

  @MainActor public var body: Content { content() }
}
