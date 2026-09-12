import Chroma
import Testing

@testable import ChromaFont

@Suite("Backend-neutral font glyphs")
struct FontGlyphTests {
  private var glyphs: [UInt32: Glyph] {
    GlyphGenerator.generated
  }

  @Test func allGlyphsAreValidTwentyByTwentyEightBitmaps() {
    #expect(!glyphs.isEmpty)
    for glyph in glyphs.values {
      #expect(glyph.rows.count == 28)
      #expect(glyph.rows.allSatisfy { $0 < (1 << 20) })
    }
  }

  @Test func shadeGlyphsHaveStandardCoverage() {
    let pixelCount = 20 * 28
    #expect(glyphs[0x2591]?.rows.reduce(0) { $0 + $1.nonzeroBitCount } == pixelCount / 4)
    #expect(glyphs[0x2592]?.rows.reduce(0) { $0 + $1.nonzeroBitCount } == pixelCount / 2)
    #expect(glyphs[0x2593]?.rows.reduce(0) { $0 + $1.nonzeroBitCount } == pixelCount * 3 / 4)
  }

  @Test func coversTerminalStructureAndPromptSymbols() {
    let required: [UInt32] = [
      0x2500,  // ─ box drawing
      0x256D,  // ╭ rounded corner
      0x2588,  // █ block
      0x2801,  // ⠁ braille
      0x279C,  // ➜ prompt
      0x2717,  // ✗ dirty marker
      0xE0B0,  // Powerline separator
      0xFFFD,  // visible unsupported-glyph fallback
    ]
    for codepoint in required {
      #expect(glyphs[codepoint] != nil)
    }
  }

  @Test func coversKeyboardAndInterfaceSymbols() {
    let required: [UInt32] = [
      0x2318,  // ⌘ Command
      0x2325,  // ⌥ Option
      0x2303,  // ⌃ Control
      0x21E7,  // ⇧ Shift
      0x21B5,  // ↵ Return
      0x2302,  // ⌂ Home/folder
      0x25A0,  // ■ Stop
      0x25C7,  // ◇ Outline diamond
      0x270E,  // ✎ Rename/edit pencil
      0x23F5,  // ⏵ Play
      0x23F9,  // ⏹ Stop control
    ]
    for codepoint in required {
      #expect(glyphs[codepoint] != nil)
    }
  }

  @Test func generatedSymbolsFitTheTextAdvance() {
    let atlas = HighResolutionFontAtlas()
    let advance = Int(FontMetrics().cellAdvance) * HighResolutionFontAtlas.scale
    #expect(advance == 36)
    for scalar in glyphs.keys {
      let index = atlas.characterIndices[scalar]!
      let x = (index % HighResolutionFontAtlas.columns) * atlas.cellWidth + HighResolutionFontAtlas.padding
      let y = (index / HighResolutionFontAtlas.columns) * atlas.cellHeight + HighResolutionFontAtlas.padding
      for row in 0..<atlas.glyphHeight {
        let start = (y + row) * atlas.width + x
        #expect(atlas.pixels[(start + advance)..<(start + atlas.glyphWidth)].allSatisfy { $0 == 0 })
        if scalar == 0x2588 {
          #expect(atlas.pixels[start..<(start + advance)].allSatisfy { $0 == 255 })
        }
        if scalar == 0x2500 {
          // Horizontal strokes must meet at both sides of consecutive cells.
          #expect(atlas.pixels[start] == atlas.pixels[start + advance - 1])
          #expect(atlas.pixels[start] == ((39..<45).contains(row) ? 255 : 0))
        }
      }
    }
  }

  @Test func halfLinesAndMixedWeightLinesMatchUnicode() throws {
    // Expected ink counts at the top, bottom, left, and right cell edges.
    let cases: [(UInt32, [Int])] = [
      (0x2574, [0, 0, 2, 0]), (0x2575, [2, 0, 0, 0]),
      (0x2576, [0, 0, 0, 2]), (0x2577, [0, 2, 0, 0]),
      (0x2578, [0, 0, 4, 0]), (0x2579, [4, 0, 0, 0]),
      (0x257A, [0, 0, 0, 4]), (0x257B, [0, 4, 0, 0]),
      (0x257C, [0, 0, 2, 4]), (0x257D, [2, 4, 0, 0]),
      (0x257E, [0, 0, 4, 2]), (0x257F, [4, 2, 0, 0]),
    ]
    for (scalar, expected) in cases {
      let glyph = try #require(glyphs[scalar])
      let edges = [
        glyph.rows[0].nonzeroBitCount, glyph.rows[27].nonzeroBitCount,
        glyph.rows.filter { $0 & (1 << 19) != 0 }.count,
        glyph.rows.filter { $0 & 1 != 0 }.count,
      ]
      #expect(edges == expected)
      // Heavy arms are solid four-pixel bands, not separated double strokes.
      if expected[0] == 4 { #expect(glyph.rows[0] == 0x00F00) }
      if expected[1] == 4 { #expect(glyph.rows[27] == 0x00F00) }
      for (edge, bit) in [(2, UInt32(1 << 19)), (3, UInt32(1))] where expected[edge] == 4 {
        #expect((0..<28).filter { glyph.rows[$0] & bit != 0 } == [12, 13, 14, 15])
      }
    }
  }

  @Test func directionalTrianglesPointInTheirNamedDirections() throws {
    func columnInk(_ glyph: Glyph, _ x: Int) -> Int {
      glyph.rows.filter { $0 & (1 << (19 - x)) != 0 }.count
    }
    let left = try #require(glyphs[0x25C0])
    let right = try #require(glyphs[0x25B6])
    let play = try #require(glyphs[0x23F5])
    #expect(columnInk(left, 2) == 2)
    #expect(columnInk(left, 17) == 14)
    #expect(columnInk(right, 2) == 14)
    #expect(columnInk(right, 17) == 2)
    #expect(columnInk(play, 4) == 17)
    #expect(columnInk(play, 16) == 1)
    for x in 2..<17 {
      #expect(columnInk(left, x) <= columnInk(left, x + 1))
      #expect(columnInk(right, x) >= columnInk(right, x + 1))
    }
    for x in 4..<16 {
      #expect(columnInk(play, x) >= columnInk(play, x + 1))
    }
  }

  @Test func coversPrintableASCII() {
    let atlas = HighResolutionFontAtlas()
    for codepoint in UInt32(0x20)...UInt32(0x7E) {
      #expect(atlas.characterIndices[codepoint] != nil)
    }
  }

  @Test func bundledCoverageHasExpectedSizeAndBlankSpace() {
    #expect(BundledFont.pixels.count == 95 * 60 * 84)
    #expect(BundledFont.pixels.prefix(60 * 84).allSatisfy { $0 == 0 })
    for scalar in 1..<95 {
      let glyph = BundledFont.pixels[(scalar * 60 * 84)..<((scalar + 1) * 60 * 84)]
      #expect(glyph.contains { $0 > 0 })
    }
  }

  @Test func highResolutionAtlasSharesCoverageAndMappingAcrossBackends() {
    let atlas = HighResolutionFontAtlas()
    #expect(atlas.glyphWidth == 60)
    #expect(atlas.glyphHeight == 84)
    #expect(atlas.pixels.count == atlas.width * atlas.height)
    #expect(atlas.pixels.contains(0))
    #expect(atlas.pixels.contains(255))
    #expect(atlas.pixels.contains { $0 > 0 && $0 < 255 })

    let a = atlas.glyphUV("A")
    let b = atlas.glyphUV("B")
    let fallback = atlas.glyphUV("�")
    #expect(a != b)
    #expect(atlas.glyphUV("🙂") == fallback)
    #expect(a.0 >= 0 && a.1 >= 0 && a.2 <= 1 && a.3 <= 1)
  }

  @Test func atlasFitsGuaranteedGLES3TextureDimensions() {
    let atlas = HighResolutionFontAtlas()
    // OpenGL ES 3 guarantees GL_MAX_TEXTURE_SIZE is at least 4096.
    // All glyphs and compositions must fit in the single shared texture.
    let guaranteedMaximumTextureSize = 4096
    #expect(atlas.width > 0 && atlas.width <= guaranteedMaximumTextureSize)
    #expect(atlas.height > 0 && atlas.height <= guaranteedMaximumTextureSize)
  }

  @Test func latinAccentsShareCellsAcrossCanonicalSpellings() {
    let atlas = HighResolutionFontAtlas()
    for entry in LatinCompositions.entries {
      let composed = Character(String(UnicodeScalar(entry.scalar)!))
      let decomposed = Character(
        String(UnicodeScalar(entry.base)!) + String(UnicodeScalar(entry.mark)!))
      let base = Character(String(UnicodeScalar(entry.base)!))
      let uv = atlas.glyphUV(composed)
      #expect(uv == atlas.glyphUV(decomposed))
      #expect(uv != atlas.glyphUV("�"))
      #expect(uv != atlas.glyphUV(base))
      #expect(uv.0 >= 0 && uv.1 >= 0 && uv.2 <= 1 && uv.3 <= 1)
      let x = Int((uv.0 * Float(atlas.width)).rounded())
      let y = Int((uv.1 * Float(atlas.height)).rounded())
      let ink = (0..<atlas.glyphHeight).reduce(0) { total, row in
        total
          + atlas.pixels[((y + row) * atlas.width + x)..<((y + row) * atlas.width + x + atlas.glyphWidth)]
          .filter { $0 != 0 }.count
      }
      #expect(ink > 0)

    }
  }

  @Test func unsupportedClustersAreNotSilentlyStripped() {
    let atlas = HighResolutionFontAtlas()
    let fallback = atlas.glyphUV("�")
    for character: Character in ["e\u{0301}\u{0308}", "e\u{0338}", "\u{0301}", "👩‍💻", "🇺🇸"] {
      #expect(atlas.glyphUV(character) == fallback)
    }

  }

  @Test func accentedTextKeepsMonospaceMeasurement() {
    let metrics = FontMetrics()
    #expect(metrics.measure("café") == metrics.measure("cafe"))
    #expect(metrics.measure("cafe\u{0301}") == metrics.measure("café"))

  }

  @Test func atlasMipmapsPreserveCoverageWhileReducingForGPUOutput() {
    let atlas = HighResolutionFontAtlas()
    let levels = atlas.mipLevels()

    #expect(levels.first?.width == atlas.width)
    #expect(levels.first?.height == atlas.height)
    #expect(levels.first?.pixels == atlas.pixels)
    #expect(levels.last?.width == 1)
    #expect(levels.last?.height == 1)

    for (parent, child) in zip(levels, levels.dropFirst()) {
      #expect(child.width == max(1, parent.width / 2))
      #expect(child.height == max(1, parent.height / 2))
      #expect(child.pixels.count == child.width * child.height)
    }

    // Filtering binary glyph coverage must produce intermediate edge samples;
    // otherwise minified GPU text would still have hard, unstable stair steps.
    #expect(
      levels.dropFirst().contains { level in
        level.pixels.contains { $0 > 0 && $0 < 255 }
      })
  }

  @Test func roundedCornersConnectTheSameEdgesAsTheirSquareEquivalents() throws {
    // ╭ ╮ ╯ ╰ must open toward the same cell edges as ┌ ┐ ┘ └: a "down"
    // corner keeps all ink in the bottom half and touches the bottom edge,
    // an "up" corner the top half and top edge, and left/right likewise.
    // Regresses a vertical flip that rendered ╭ as ╰.
    func rowHasInk(_ glyph: Glyph, _ y: Int) -> Bool { glyph.rows[y] != 0 }
    func columnHasInk(_ glyph: Glyph, _ x: Int) -> Bool {
      (0..<28).contains { glyph.rows[$0] & (1 << (19 - x)) != 0 }
    }

    let downRight = try #require(glyphs[0x256D])  // ╭
    let downLeft = try #require(glyphs[0x256E])  // ╮
    let upLeft = try #require(glyphs[0x256F])  // ╯
    let upRight = try #require(glyphs[0x2570])  // ╰

    // The middle band is rows 13...14; the 2px brush may spill one row past
    // it, so the empty halves are asserted with one row of slack.
    for (glyph, name) in [(downRight, "╭"), (downLeft, "╮")] {
      for y in 0...11 {
        #expect(!rowHasInk(glyph, y), "\(name) must not ink row \(y) above the middle band")
      }
      #expect(rowHasInk(glyph, 27), "\(name) must touch the bottom edge")
    }
    for (glyph, name) in [(upLeft, "╯"), (upRight, "╰")] {
      for y in 16...27 {
        #expect(!rowHasInk(glyph, y), "\(name) must not ink row \(y) below the middle band")
      }
      #expect(rowHasInk(glyph, 0), "\(name) must touch the top edge")
    }

    #expect(columnHasInk(downRight, 19) && !columnHasInk(downRight, 0))  // ╭ opens right, not left
    #expect(columnHasInk(downLeft, 0) && !columnHasInk(downLeft, 19))  // ╮
    #expect(columnHasInk(upLeft, 0) && !columnHasInk(upLeft, 19))  // ╯
    #expect(columnHasInk(upRight, 19) && !columnHasInk(upRight, 0))  // ╰
  }
}
