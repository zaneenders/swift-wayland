import CEGL
import CGLES3

extension Wayland {

  static func compileShader(_ type: GLenum, _ src: String) -> GLuint {
    let s = glCreateShader(type)
    unsafe src.withCString { cstr in
      var p: UnsafePointer<GLchar>? = unsafe UnsafePointer(cstr)
      var len = GLint(src.utf8.count)
      unsafe glShaderSource(s, 1, &p, &len)
    }
    glCompileShader(s)
    var ok: GLint = 0
    unsafe glGetShaderiv(s, EGLenum(GL_COMPILE_STATUS), &ok)
    if ok == 0 {
      var logLen: GLint = 0
      unsafe glGetShaderiv(s, EGLenum(GL_INFO_LOG_LENGTH), &logLen)
      var buf = [UInt8](repeating: 0, count: Int(logLen))
      unsafe glGetShaderInfoLog(s, logLen, nil, &buf)
      let msg = String(decoding: buf, as: UTF8.self)
      fatalError("Shader compile error: \(msg)")
    }
    return s
  }

  static func linkProgram(vs: GLuint, fs: GLuint) -> GLuint {
    let p = glCreateProgram()
    glAttachShader(p, vs)
    glAttachShader(p, fs)
    glLinkProgram(p)
    var ok: GLint = 0
    unsafe glGetProgramiv(p, GLenum(GL_LINK_STATUS), &ok)
    if ok == 0 {
      var logLen: GLint = 0
      unsafe glGetProgramiv(p, GLenum(GL_INFO_LOG_LENGTH), &logLen)
      let buf = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLen))
      defer { unsafe buf.deallocate() }
      unsafe glGetProgramInfoLog(p, GLsizei(logLen), nil, buf)
      let msg = unsafe String(cString: buf)
      fatalError("Program link error: \(msg)")
    }
    glDeleteShader(vs)
    glDeleteShader(fs)
    return p
  }

  static func initGL() {
    let quadVerts: [Float] = [
      -1.0, 1.0,  // TL
      1.0, 1.0,  // TR
      -1.0, -1.0,  // BL
      1.0, -1.0,  // BR
    ]
    let vs = compileShader(GLenum(GL_VERTEX_SHADER), loadText(resource: "vertex.glsl"))
    let fs = compileShader(GLenum(GL_FRAGMENT_SHADER), loadText(resource: "fragment.glsl"))
    program = linkProgram(vs: vs, fs: fs)

    glEnable(GLenum(GL_BLEND))
    glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    unsafe glGenVertexArrays(1, &vao)
    glBindVertexArray(vao)

    unsafe glGenBuffers(1, &quadVBO)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), quadVBO)
    unsafe quadVerts.withUnsafeBytes { ptr in
      unsafe glBufferData(GLenum(GL_ARRAY_BUFFER), ptr.count, ptr.baseAddress, GLenum(GL_STATIC_DRAW))
    }
    glEnableVertexAttribArray(0)
    unsafe glVertexAttribPointer(
      0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 2 * GLint(MemoryLayout<Float>.size),
      UnsafeRawPointer(bitPattern: 0))

    unsafe glGenBuffers(1, &instanceVBO)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
    glBufferData(
      GLenum(GL_ARRAY_BUFFER), 4000 * MemoryLayout<RenderableQuad>.stride, nil, GLenum(GL_DYNAMIC_DRAW))

    let stride = GLsizei(MemoryLayout<RenderableQuad>.stride)
    glEnableVertexAttribArray(1)
    unsafe glVertexAttribPointer(
      1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: 0 + 0))
    glVertexAttribDivisor(1, 1)

    let off_dst_p1 = MemoryLayout<(Float, Float)>.stride
    glEnableVertexAttribArray(2)
    unsafe glVertexAttribPointer(
      2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_dst_p1))
    glVertexAttribDivisor(2, 1)

    let off_tex_tl = off_dst_p1 + MemoryLayout<(Float, Float)>.stride
    glEnableVertexAttribArray(3)
    unsafe glVertexAttribPointer(
      3, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_tl))
    glVertexAttribDivisor(3, 1)

    let off_tex_br = off_tex_tl + MemoryLayout<(Float, Float)>.stride
    glEnableVertexAttribArray(4)
    unsafe glVertexAttribPointer(
      4, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_br))
    glVertexAttribDivisor(4, 1)

    let off_color = off_tex_br + MemoryLayout<(Float, Float)>.stride
    glEnableVertexAttribArray(5)
    unsafe glVertexAttribPointer(
      5, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_color))
    glVertexAttribDivisor(5, 1)

    let off_border_color = off_color + MemoryLayout<RGB>.stride
    glEnableVertexAttribArray(6)
    unsafe glVertexAttribPointer(
      6, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_border_color))
    glVertexAttribDivisor(6, 1)

    let off_border_width = off_border_color + MemoryLayout<RGB>.stride
    glEnableVertexAttribArray(7)
    unsafe glVertexAttribPointer(
      7, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_border_width))
    glVertexAttribDivisor(7, 1)

    let off_corner_radius = off_border_width + MemoryLayout<Float>.stride
    glEnableVertexAttribArray(8)
    unsafe glVertexAttribPointer(
      8, 1, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_corner_radius))
    glVertexAttribDivisor(8, 1)

    unsafe glGenTextures(1, &whiteTex)
    glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
    let px: [UInt8] = [255, 255, 255, 255]
    unsafe px.withUnsafeBytes { p in
      unsafe glTexImage2D(
        GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA), 1, 1, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE),
        p.baseAddress)
    }
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)

    createFontAtlas()

    uTex = unsafe glGetUniformLocation(program, "uTex")
    uRes = unsafe glGetUniformLocation(program, "uRes")
  }
}
