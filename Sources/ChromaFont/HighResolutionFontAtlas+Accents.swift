extension HighResolutionFontAtlas {
  /// Fit the base's ink into the existing cell with room for a small authored
  /// mark. This deliberately trades some vertical detail for stable cell bounds:
  /// neither renderers nor selection/culling need special overhang handling.
  static func composeAccent(
    pixels: inout [UInt8], width: Int, cellWidth: Int, cellHeight: Int,
    baseIndex: Int, destinationIndex: Int, base: UInt32, mark: UInt32
  ) {
    let w = sourceGlyphWidth * scale
    let h = sourceGlyphHeight * scale
    let sourceX = (baseIndex % columns) * cellWidth + padding
    let sourceY = (baseIndex / columns) * cellHeight + padding
    let destinationX = (destinationIndex % columns) * cellWidth + padding
    let destinationY = (destinationIndex / columns) * cellHeight + padding
    let below = mark == 0x327 || mark == 0x328
    let pattern = LatinCompositions.marks[mark]!
    let markHeight = pattern.count * scale
    var minX = w
    var maxX = 0
    var minY = h
    var maxY = 0
    var occupiedRows = [Bool](repeating: false, count: h)
    for y in 0..<h {
      for x in 0..<w where pixels[(sourceY + y) * width + sourceX + x] != 0 {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
        occupiedRows[y] = true
      }
    }
    guard minY <= maxY else { return }

    // Above accents replace the detached dot on lowercase i/j. Preserve the
    // stem and descender rather than painting the accent on top of the dot.
    if !below && (base == 0x69 || base == 0x6A) {
      var y = minY
      while y <= maxY && occupiedRows[y] { y += 1 }
      while y <= maxY && !occupiedRows[y] { y += 1 }
      if y <= maxY { minY = y }
    }

    let gap = scale
    let reserved = markHeight + gap
    let top = below ? minY : max(minY, reserved)
    let bottom = below ? min(maxY, h - reserved - 1) : maxY
    guard top <= bottom else { return }
    let sourceHeight = maxY - minY + 1
    let destinationHeight = bottom - top + 1
    for y in top...bottom {
      let sourceRow = minY + (y - top) * sourceHeight / destinationHeight
      for x in minX...maxX {
        pixels[(destinationY + y) * width + destinationX + x] =
          pixels[(sourceY + sourceRow) * width + sourceX + x]
      }
    }

    let markWidth = pattern[0].count * scale
    let markX = max(0, min(w - markWidth, (minX + maxX + 1 - markWidth) / 2))
    let markY = below ? bottom + gap + 1 : top - gap - markHeight
    for (row, line) in pattern.enumerated() {
      for (column, pixel) in line.enumerated() where pixel == "#" {
        for dy in 0..<scale {
          for dx in 0..<scale {
            let x = destinationX + markX + column * scale + dx
            let y = destinationY + markY + row * scale + dy
            pixels[y * width + x] = 255
          }
        }
      }
    }
  }
}
