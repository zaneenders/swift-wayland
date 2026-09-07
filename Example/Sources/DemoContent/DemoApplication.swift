import Chroma

@MainActor
public struct DemoApplication: App {
  private let state: PerformanceDemoState
  private let shortcutModifier: KeyModifiers

  public init() {
    #if os(macOS)
    self.init(shortcutModifier: .command)
    #else
    self.init(shortcutModifier: .superKey)
    #endif
  }

  public init(itemCount: Int = 2_000, shortcutModifier: KeyModifiers) {
    state = PerformanceDemoState(itemCount: itemCount)
    self.shortcutModifier = shortcutModifier
  }

  public var title: String { "Chroma Demo" }
  public var windowSize: Size { Size(width: 1100, height: 720) }
  public var minimumRefreshRate: Double { 30 }

  public var keyBindings: KeyBindings {
    KeyBindings {
      bind("c", modifiers: shortcutModifier, to: .editing(.copy))
      bind("x", modifiers: shortcutModifier, to: .editing(.cut))
      bind("v", modifiers: shortcutModifier, to: .editing(.paste))
      bind("a", modifiers: shortcutModifier, to: .editing(.selectAll))
      bind(.backspace, to: .editing(.backspace))
      bind(.delete, to: .editing(.deleteForward))
      bind(.leftArrow, to: .editing(.moveCaretLeft))
      bind(.rightArrow, to: .editing(.moveCaretRight))
      bind(.upArrow, to: .editing(.moveCaretUp))
      bind(.downArrow, to: .editing(.moveCaretDown))
      bind(.upArrow, modifiers: .shift, to: .editing(.selectCaretUp))
      bind(.downArrow, modifiers: .shift, to: .editing(.selectCaretDown))
      bind(.home, to: .editing(.moveCaretToStart))
      bind(.end, to: .editing(.moveCaretToEnd))
      bind(.enter, to: .editing(.submit))
      bind(.escape, to: .editing(.endEditing))
      bind(.space, to: .action(.activate))
      bind(.pageUp, to: .navigation(.pageUp))
      bind(.pageDown, to: .navigation(.pageDown))
      bind("j", to: .navigation(.down))
      bind("f", to: .navigation(.up))
      bind("d", to: .navigation(.left))
      bind("k", to: .navigation(.right))
      bind("l", to: .navigation(.in))
      bind("s", to: .navigation(.out))
    }
  }

  // The current remote input adapter resolves an explicit editing overlay,
  // whereas native input lets printable movement keys insert text while editing.
  public var editingKeyBindings: KeyBindings {
    keyBindings.overlay {
      bind("j", to: .editing(.insert("j")))
      bind("f", to: .editing(.insert("f")))
      bind("d", to: .editing(.insert("d")))
      bind("k", to: .editing(.insert("k")))
      bind("l", to: .editing(.insert("l")))
      bind("s", to: .editing(.insert("s")))
      bind(.space, to: .editing(.insert(" ")))
    }
  }

  public var body: some Block {
    PerformanceDemo(state: state).chromaTheme(.dark)
  }
}
