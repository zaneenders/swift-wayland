# Bundled bitmap font

Chroma renders bundled coverage bitmaps without a runtime font library. ASCII
and generated terminal symbols retain their existing mappings and advances.

## Latin accents

The atlas builds 190 additional canonical Latin compositions for each face from
an ASCII letter and one supported accent. Swift `Character` dictionary equality
maps precomposed and canonically equivalent decomposed spellings to the same
cell, without rewriting application text. Examples include `café`, `Ångström`,
`naïve`, `façade`, and `Český`.

Accent patterns and repertoire selection live in
`Sources/LatinCompositionGenerator/main.swift`. The SwiftPM build-tool plugin
`LatinCompositionPlugin` automatically generates `LatinCompositions.swift` into
its build directory and compiles it into `ChromaFont`. No generated source is
checked in or written into the source tree. Generator changes invalidate the
output; unchanged builds reuse it.

Build or test normally:

```sh
swift build
swift test --filter FontGlyphTests
```

The generator uses Swift and Foundation's Unicode canonical decomposition
for U+00C0–U+024F, retaining only ASCII-letter + one supported mark pairs. It does
not import fonts or add a runtime dependency.

`HighResolutionFontAtlas+Accents.swift` composes existing base coverage with
small authored marks. Where necessary it compresses the base vertically to
reserve accent space inside the existing 20×28 logical canvas. Detached dots on
lowercase i/j are removed for above accents. These are pragmatic bitmap designs,
not a claim of language-specific typographic fidelity; visual refinement can be
done independently of the renderer.

Every supported composition occupies one cell, so existing measurement, hit
testing, remote transport, and both GPU backends retain their grid behavior.
The atlas is still a single texture; paging remains future work before major
repertoire growth.

## Explicit limitations

This is not general Unicode shaping. Unsupported base/mark combinations,
stacked accents, isolated marks, emoji sequences, and unsupported scripts still
use a visible replacement glyph. Marks are never silently discarded. Greek,
Cyrillic, CJK/wide-cell layout, bidi, and contextual shaping are not added by
this change. Additional bitmap coverage and a positioned-glyph interface can be
introduced incrementally when those features are implemented.
