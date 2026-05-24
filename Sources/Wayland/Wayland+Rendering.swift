import CGLES3

extension Wayland {

  // MARK: - Renderer Protocol Conformance

  static func drawQuad(_ quad: RenderableQuad) {
    glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
    let rects: InlineArray<1, RenderableQuad> = [quad]
    unsafe rects.span.withUnsafeBytes { buf in
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
      unsafe glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, MemoryLayout<RenderableQuad>.stride, buf.baseAddress)
    }
    glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, 1)
  }

  static func drawText(_ text: RenderableText) {
    var penX = text.pos.x
    let penY = text.pos.y

    var totalWidth: UInt = 0
    for _ in text.text {
      let w = glyphW * text.scale
      totalWidth += w + glyphSpacing * text.scale
    }
    if !text.text.isEmpty {
      totalWidth -= glyphSpacing * text.scale
    }

    let textHeight = glyphH * text.scale

    drawQuad(
      RenderableQuad(
        dst_p0: (penX, penY),
        dst_p1: (penX + totalWidth, penY + textHeight),
        tex_tl: (0, 0),
        tex_br: (1, 1),
        color: text.background
      )
    )

    // Draw text
    glBindTexture(GLenum(GL_TEXTURE_2D), fontTex)
    var symbols = ContiguousArray<RenderableQuad>(
      repeating:
        RenderableQuad(
          dst_p0: (0, 0),
          dst_p1: (0, 0),
          tex_tl: (0, 0),
          tex_br: (0, 0),
          color: text.foreground
        ), count: text.text.length)

    penX = text.pos.x

    for (i, c) in text.text.utf8.enumerated() {
      let (u0, v0, u1, v1) = glyphUV(c)
      let w = glyphW * text.scale
      let h = glyphH * text.scale
      symbols[i] = RenderableQuad(
        dst_p0: (penX, penY),
        dst_p1: (penX + w, penY + h),
        tex_tl: (u0, v0),
        tex_br: (u1, v1),
        color: text.foreground
      )
      penX += w + glyphSpacing * text.scale
    }

    guard !symbols.isEmpty else { return }

    unsafe symbols.withUnsafeBytes { buf in
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
      unsafe glBufferSubData(
        GLenum(GL_ARRAY_BUFFER), 0, symbols.count * MemoryLayout<RenderableQuad>.stride, buf.baseAddress)
    }
    glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(symbols.count))
  }
}
