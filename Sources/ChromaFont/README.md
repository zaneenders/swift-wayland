# Bundled font

Chroma uses **one** text font: a rasterized subset of Noto Sans Mono Regular
2.007, with a 12-point monospace advance. There is no font-face selector.
Generated terminal and interface symbols supplement the font, not a second
ASCII alphabet.
There is no runtime font lookup or font rasterizer dependency.

## License and provenance

The font and derived bitmap coverage are distributed under **SIL OFL 1.1**.
The exact TTF embeds `Copyright 2015-2021 Google LLC. All Rights Reserved.`
and explicitly states SIL OFL 1.1. The upstream repository also includes the
Noto Project Authors copyright notice. Both are preserved with the full license
in [Resources/OFL.txt](Resources/OFL.txt), copied into ChromaFont's SwiftPM
resource bundle. Applications must ship that bundle (or an accessible copy of
the notice and license) with distributed binaries. This does not license the
application itself under OFL. No Reserved Font Names are specified in the
source copyright notices.

Pinned upstream revision: `ffebf8c1ee449e544955a7e813c54f9b73848eac`.

- [Original TTF](https://raw.githubusercontent.com/notofonts/noto-fonts/ffebf8c1ee449e544955a7e813c54f9b73848eac/hinted/ttf/NotoSansMono/NotoSansMono-Regular.ttf)
- [Upstream license](https://raw.githubusercontent.com/notofonts/noto-fonts/ffebf8c1ee449e544955a7e813c54f9b73848eac/LICENSE)
- TTF SHA-256: `d9e2b23d19f8230be7146f409a52b1d23117e635e28f2e2892cf91b7382f325b`

`BundledFontPlugin` runs the Swift `BundledFontGenerator` during normal builds.
It validates `FontData/BundledFont.rle` and generates `BundledFont.swift` in the
SwiftPM plugin work directory. Both the input and generator executable are
tracked, so unchanged builds reuse the output. No Python, network access, or
system font lookup is required.

```sh
swift build
swift test --filter FontGlyphTests
```

The checked-in RLE file preserves the existing rasterized printable ASCII
coverage byte-for-byte. Each record is a nonzero unsigned 16-bit big-endian run
length followed by an 8-bit coverage value. The decoded data contains 95
row-major 60×84 glyphs ordered from U+0020 through U+007E. The generator rejects
malformed records and incorrect decoded lengths.

This is source generation from pinned bitmap coverage, not a TTF rasterizer.
The original coverage was rasterized with Pillow 11.3.0 from the pinned TTF at
60 px, with a baseline at 65 px and a 36 px advance. Changing the underlying
TTF requires a separate rasterization step; the build plugin does not interpret
TTF files. The converted subset is named Chroma's bundled font, not an
unmodified Noto font.

## Latin accents

The atlas builds 190 additional canonical Latin compositions from
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
