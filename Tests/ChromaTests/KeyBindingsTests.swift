import Testing

@testable import Chroma

struct KeyBindingsTests {
  @Test func physicalCommandAndSuperAreDistinct() {
    #expect(KeyModifiers.command != KeyModifiers.superKey)
    #expect(!KeyModifiers.command.contains(.superKey))
    #expect(!KeyModifiers.superKey.contains(.command))
  }

  @Test func physicalModifiersCombineWithOtherModifiers() {
    for systemModifier in [KeyModifiers.command, .superKey] {
      let bindings = KeyBindings {
        bind("l", modifiers: [systemModifier, .shift], to: .editing(.selectAll))
      }

      #expect(
        bindings.command(for: KeyChord("l", modifiers: [systemModifier, .shift]))
          == .some(.some(.editing(.selectAll))))
      #expect(bindings.command(for: KeyChord("l", modifiers: systemModifier)) == nil)
    }
  }
}

struct TextInsertionRoutingTests {
  @Test func printableShortcutsRemainTextWhileEditing() {
    for (chord, text) in [(KeyChord(.space), " "), (KeyChord("f"), "f"), (KeyChord("j"), "j"), (KeyChord("f", modifiers: .shift), "F")] {
      #expect(KeyBindings().prefersTextInsertion(chord: chord, text: text, isTextEditing: true))
      #expect(!KeyBindings().prefersTextInsertion(chord: chord, text: text, isTextEditing: false))
    }
  }

  @Test func modifiedShortcutsAndNonTextKeysKeepTheirBindings() {
    for modifier: KeyModifiers in [.command, .control, .superKey] {
      #expect(!KeyBindings().prefersTextInsertion(
        chord: KeyChord("v", modifiers: modifier), text: "v", isTextEditing: true))
    }
    #expect(!KeyBindings().prefersTextInsertion(chord: KeyChord(.enter), text: nil, isTextEditing: true))
    #expect(!KeyBindings().prefersTextInsertion(chord: KeyChord(.space), text: "", isTextEditing: true))
  }
}
