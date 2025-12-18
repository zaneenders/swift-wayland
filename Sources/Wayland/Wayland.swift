import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CWaylandProtocols
import Foundation

/// There is alot of global state here to setup and conform to Wayland's patterns.
/// Their might be better ways to abstract this and clean it up a bit. But it's
/// working for now.
@MainActor
public enum Wayland {

  @MainActor struct Glyph {
    var rows: [String] = Array(repeating: "", count: Int(glyphH))
  }

  public enum State {
    case running
    case error(reason: String)
    case exit

    var isRunning: Bool {
      switch self {
      case .running: true
      case .error, .exit: false
      }
    }
  }

  public internal(set) static var state: State = .running

  public static func exit() {
    state = .exit
  }

  public static let glyphW: UInt = 5
  public static let glyphH: UInt = 7
  public static let glyphSpacing: UInt = 1
  public static let scale: UInt = 12

  static let firstChar: UInt8 = 32
  static let lastChar: UInt8 = 126
  static let charCount = UInt(lastChar - firstChar + 1)
  static var atlasW = Int(charCount * (glyphW + glyphSpacing))
  static var atlasH = Int(glyphH)

  static var winW: UInt32 = 800
  #if Toolbar
  static var winH: UInt32 = UInt32(toolbar_height)
  #else
  static var winH: UInt32 = 600
  #endif

  static var eglDisplay: EGLDisplay?
  static var eglContext: EGLContext?
  static var eglSurface: EGLSurface?
  static var eglWindow: OpaquePointer?

  static let EGL_NO_CONTEXT: EGLContext? = unsafe EGLContext(bitPattern: 0)
  static let EGL_NO_DISPLAY: EGLDisplay? = unsafe EGLDisplay(bitPattern: 0)
  static let EGL_NO_SURFACE: EGLSurface? = unsafe EGLSurface(bitPattern: 0)

  static var program: GLuint = 0
  static var vao: GLuint = 0
  static var fontTex: GLuint = 0
  static var whiteTex: GLuint = 0
  static var quadVBO: GLuint = 0
  static var instanceVBO: GLuint = 0
  static var uRes: GLint = 0
  static var uTex: GLint = 0

  nonisolated(unsafe) static var display: OpaquePointer!
  static var registry: OpaquePointer!
  static var compositor: OpaquePointer!
  static var wmBase: OpaquePointer!
  static var seat: OpaquePointer!
  static var surface: OpaquePointer!
  static var toplevel: OpaquePointer!
  static var keyboard: OpaquePointer!
  #if Toolbar
  static var layerShell: OpaquePointer?
  static var layerSurface: OpaquePointer?

  public static let toolbar_height: UInt = 20
  #else
  static var xdgSurface: OpaquePointer!
  #endif

  static func initEGL() throws(WaylandError) {
    unsafe eglDisplay = eglGetDisplay(EGLNativeDisplayType(display))
    guard unsafe eglDisplay != nil else { throw WaylandError.error(message: "eglGetDisplay failed") }
    guard unsafe eglInitialize(eglDisplay, nil, nil) == EGL_TRUE else {
      throw WaylandError.error(message: "eglInitialize failed")
    }

    guard eglBindAPI(EGLenum(EGL_OPENGL_ES_API)) == EGL_TRUE else {
      throw WaylandError.error(message: "eglBindAPI failed")
    }

    var cfg: EGLConfig?
    var num: EGLint = 0
    var attrs: [EGLint] = [
      EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
      EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
      EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
      EGL_NONE,
    ]
    unsafe attrs.withUnsafeMutableBufferPointer { p in
      _ = unsafe eglChooseConfig(eglDisplay, p.baseAddress, &cfg, 1, &num)
    }
    guard num > 0, unsafe cfg != nil else { throw WaylandError.error(message: "eglChooseConfig failed") }

    var ctxAttrs: [EGLint] = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE]
    unsafe eglContext = ctxAttrs.withUnsafeMutableBufferPointer { p in
      unsafe eglCreateContext(eglDisplay, cfg, EGL_NO_CONTEXT, p.baseAddress)
    }
    guard unsafe eglContext != EGL_NO_CONTEXT else { throw WaylandError.error(message: "eglCreateContext failed") }

    unsafe eglWindow = wl_egl_window_create(surface, Int32(winW), Int32(winH))
    guard unsafe eglWindow != nil else { throw WaylandError.error(message: "wl_egl_window_create failed") }

    unsafe eglSurface = eglCreateWindowSurface(eglDisplay, cfg, EGLNativeWindowType(bitPattern: eglWindow), nil)
    guard unsafe eglSurface != EGL_NO_SURFACE else {
      throw WaylandError.error(message: "eglCreateWindowSurface failed")
    }
    guard unsafe eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext) == EGL_TRUE else {
      throw WaylandError.error(message: "eglMakeCurrent failed")
    }

    _ = unsafe eglSwapInterval(eglDisplay, 1)
  }

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

  static func loadText(resource name: String) -> String {
    // TODO: Loaded sharders at compile time.
    let url = Bundle.module.url(forResource: name, withExtension: nil)!
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
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
      GLenum(GL_ARRAY_BUFFER), 4000 * MemoryLayout<Quad>.stride, nil, GLenum(GL_DYNAMIC_DRAW))

    let stride = GLsizei(MemoryLayout<Quad>.stride)
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

  static func initFont() -> [Glyph] {
    var font5x7 = Array(repeating: Glyph(), count: 128)
    func set(_ ch: Character, _ rows: [String]) {
      let i = Int(ch.unicodeScalars.first!.value)
      font5x7[i] = Glyph(rows: rows)
    }
    set(" ", ["00000", "00000", "00000", "00000", "00000", "00000", "00000"])
    set("!", ["00100", "00100", "00100", "00100", "00100", "00000", "00100"])
    set("\"", ["01010", "01010", "01010", "00000", "00000", "00000", "00000"])
    set("#", ["01010", "01010", "11111", "01010", "11111", "01010", "01010"])
    set("$", ["00100", "01111", "10100", "01110", "00101", "11110", "00100"])
    set("%", ["11000", "11001", "00010", "00100", "01000", "10011", "00011"])
    set("&", ["01100", "10010", "10100", "01000", "10101", "10010", "01101"])
    set("'", ["00100", "00100", "00100", "00000", "00000", "00000", "00000"])
    set("(", ["00010", "00100", "01000", "01000", "01000", "00100", "00010"])
    set(")", ["01000", "00100", "00010", "00010", "00010", "00100", "01000"])
    set("*", ["00100", "10101", "01110", "00100", "01110", "10101", "00100"])
    set("+", ["00000", "00100", "00100", "11111", "00100", "00100", "00000"])
    set(",", ["00000", "00000", "00000", "00000", "00100", "00100", "01000"])
    set("-", ["00000", "00000", "00000", "11111", "00000", "00000", "00000"])
    set(".", ["00000", "00000", "00000", "00000", "00000", "00110", "00110"])
    set("/", ["00001", "00010", "00100", "01000", "10000", "00000", "00000"])
    set("0", ["01110", "10001", "10011", "10101", "11001", "10001", "01110"])
    set("1", ["00100", "01100", "00100", "00100", "00100", "00100", "01110"])
    set("2", ["01110", "10001", "00001", "00110", "01000", "10000", "11111"])
    set("3", ["11110", "00001", "00001", "01110", "00001", "00001", "11110"])
    set("4", ["00010", "00110", "01010", "10010", "11111", "00010", "00010"])
    set("5", ["11111", "10000", "11110", "00001", "00001", "10001", "01110"])
    set("6", ["01110", "10000", "11110", "10001", "10001", "10001", "01110"])
    set("7", ["11111", "00001", "00010", "00100", "01000", "01000", "01000"])
    set("8", ["01110", "10001", "10001", "01110", "10001", "10001", "01110"])
    set("9", ["01110", "10001", "10001", "01111", "00001", "00001", "01110"])
    set(":", ["00000", "00110", "00110", "00000", "00110", "00110", "00000"])
    set(";", ["00000", "00110", "00110", "00000", "00110", "00100", "01000"])
    set("<", ["00010", "00100", "01000", "10000", "01000", "00100", "00010"])
    set("=", ["00000", "00000", "11111", "00000", "11111", "00000", "00000"])
    set(">", ["01000", "00100", "00010", "00001", "00010", "00100", "01000"])
    set("?", ["01110", "10001", "00001", "00010", "00100", "00000", "00100"])
    set("@", ["01110", "10001", "10111", "10101", "10111", "10000", "01110"])
    set("A", ["01110", "10001", "10001", "11111", "10001", "10001", "10001"])
    set("B", ["11110", "10001", "10001", "11110", "10001", "10001", "11110"])
    set("C", ["01110", "10001", "10000", "10000", "10000", "10001", "01110"])
    set("D", ["11110", "10001", "10001", "10001", "10001", "10001", "11110"])
    set("E", ["11111", "10000", "10000", "11110", "10000", "10000", "11111"])
    set("F", ["11111", "10000", "10000", "11110", "10000", "10000", "10000"])
    set("G", ["01110", "10001", "10000", "10111", "10001", "10001", "01110"])
    set("H", ["10001", "10001", "10001", "11111", "10001", "10001", "10001"])
    set("I", ["01110", "00100", "00100", "00100", "00100", "00100", "01110"])
    set("J", ["00001", "00001", "00001", "00001", "10001", "10001", "01110"])
    set("K", ["10001", "10010", "10100", "11000", "10100", "10010", "10001"])
    set("L", ["10000", "10000", "10000", "10000", "10000", "10000", "11111"])
    set("M", ["10001", "11011", "10101", "10101", "10001", "10001", "10001"])
    set("N", ["10001", "10001", "11001", "10101", "10011", "10001", "10001"])
    set("O", ["01110", "10001", "10001", "10001", "10001", "10001", "01110"])
    set("P", ["11110", "10001", "10001", "11110", "10000", "10000", "10000"])
    set("Q", ["01110", "10001", "10001", "10001", "10101", "10010", "01101"])
    set("R", ["11110", "10001", "10001", "11110", "10100", "10010", "10001"])
    set("S", ["01110", "10001", "10000", "01110", "00001", "10001", "01110"])
    set("T", ["11111", "00100", "00100", "00100", "00100", "00100", "00100"])
    set("U", ["10001", "10001", "10001", "10001", "10001", "10001", "01110"])
    set("V", ["10001", "10001", "10001", "10001", "10001", "01010", "00100"])
    set("W", ["10001", "10001", "10001", "10101", "10101", "10101", "01010"])
    set("X", ["10001", "10001", "01010", "00100", "01010", "10001", "10001"])
    set("Y", ["10001", "10001", "01010", "00100", "00100", "00100", "00100"])
    set("Z", ["11111", "00001", "00010", "00100", "01000", "10000", "11111"])
    set("[", ["01110", "01000", "01000", "01000", "01000", "01000", "01110"])
    set("\\", ["10000", "01000", "00100", "00010", "00001", "00000", "00000"])
    set("]", ["01110", "00010", "00010", "00010", "00010", "00010", "01110"])
    set("^", ["00100", "01010", "10001", "00000", "00000", "00000", "00000"])
    set("_", ["00000", "00000", "00000", "00000", "00000", "00000", "11111"])
    set("`", ["01000", "00100", "00010", "00000", "00000", "00000", "00000"])
    set("a", ["00000", "00000", "01110", "00001", "01111", "10001", "01111"])
    set("b", ["10000", "10000", "11110", "10001", "10001", "10001", "11110"])
    set("c", ["00000", "00000", "01110", "10000", "10000", "10001", "01110"])
    set("d", ["00001", "00001", "01111", "10001", "10001", "10001", "01111"])
    set("e", ["00000", "00000", "01110", "10001", "11111", "10000", "01110"])
    set("f", ["00110", "01001", "01000", "11100", "01000", "01000", "01000"])
    set("g", ["00000", "00000", "01111", "10001", "01111", "00001", "01110"])
    set("h", ["10000", "10000", "11110", "10001", "10001", "10001", "10001"])
    set("i", ["00100", "00000", "01100", "00100", "00100", "00100", "01110"])
    set("j", ["00010", "00000", "00110", "00010", "00010", "10010", "01100"])
    set("k", ["10000", "10000", "10010", "10100", "11000", "10100", "10010"])
    set("l", ["01100", "00100", "00100", "00100", "00100", "00100", "01110"])
    set("m", ["00000", "00000", "11010", "10101", "10101", "10101", "10101"])
    set("n", ["00000", "00000", "11110", "10001", "10001", "10001", "10001"])
    set("o", ["00000", "00000", "01110", "10001", "10001", "10001", "01110"])
    set("p", ["00000", "00000", "11110", "10001", "11110", "10000", "10000"])
    set("q", ["00000", "00000", "01111", "10001", "01111", "00001", "00001"])
    set("r", ["00000", "00000", "10110", "11001", "10000", "10000", "10000"])
    set("s", ["00000", "00000", "01111", "10000", "01110", "00001", "11110"])
    set("t", ["01000", "01000", "11100", "01000", "01000", "01001", "00110"])
    set("u", ["00000", "00000", "10001", "10001", "10001", "10001", "01111"])
    set("v", ["00000", "00000", "10001", "10001", "10001", "01010", "00100"])
    set("w", ["00000", "00000", "10001", "10001", "10101", "10101", "01010"])
    set("x", ["00000", "00000", "10001", "01010", "00100", "01010", "10001"])
    set("y", ["00000", "00000", "10001", "10001", "01111", "00001", "01110"])
    set("z", ["00000", "00000", "11111", "00010", "00100", "01000", "11111"])
    set("{", ["00110", "00100", "00100", "01100", "00100", "00100", "00110"])
    set("|", ["00100", "00100", "00100", "00100", "00100", "00100", "00100"])
    set("}", ["01100", "00100", "00100", "00110", "00100", "00100", "01100"])
    set("~", ["01001", "10110", "00000", "00000", "00000", "00000", "00000"])

    return font5x7
  }

  static func createFontAtlas() {
    let font5x7 = initFont()
    let pixelsCount = Int(atlasW * atlasH * 4)
    let img = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelsCount)
    unsafe img.initialize(repeating: 0, count: pixelsCount)
    defer { unsafe img.deallocate() }

    for c in Int(firstChar)...Int(lastChar) {
      let g = font5x7[c]
      let xoff = Int(c - Int(firstChar)) * Int(glyphW + glyphSpacing)
      if !g.rows[0].isEmpty {
        for y in 0..<Int(glyphH) {
          let row = Array(g.rows[y])
          for x in 0..<Int(glyphW) {
            let bit = row[x] == "1"
            let idx = Int(y * atlasW + xoff + x) * 4
            unsafe img[idx + 0] = 255
            unsafe img[idx + 1] = 255
            unsafe img[idx + 2] = 255
            unsafe img[idx + 3] = bit ? 255 : 0
          }
        }
      }
    }

    unsafe glGenTextures(1, &fontTex)
    glBindTexture(GLenum(GL_TEXTURE_2D), fontTex)
    glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
    unsafe glTexImage2D(
      GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA8), GLsizei(atlasW), GLsizei(atlasH), 0, GLenum(GL_RGBA),
      GLenum(GL_UNSIGNED_BYTE), img)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
  }

  static func glyphUV(_ c: UInt8) -> (Float, Float, Float, Float) {
    var ch = c
    if ch < firstChar || ch > lastChar { ch = 32 }
    let idx = Int(ch - firstChar)
    let xoff = idx * (Int(glyphW) + Int(glyphSpacing))
    let u0 = Float(xoff) / Float(atlasW)
    let u1 = Float(xoff + Int(glyphW)) / Float(atlasW)
    let v0 = Float(1.0) - Float(glyphH) / Float(atlasH)
    let v1 = Float(1.0)
    return (u0, v0, u1, v1)
  }

  static func drawQuad(_ quad: Quad, _ r: borrowing Renderer? = nil) {
    glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
    let rects: InlineArray<1, Quad> = [quad]
    unsafe rects.span.withUnsafeBytes { buf in
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
      unsafe glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, MemoryLayout<Quad>.stride, buf.baseAddress)
    }
    glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, 1)
  }

  static func drawText(_ text: Text, _ r: borrowing Renderer? = nil) {
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
      Quad(
        dst_p0: (penX, penY),
        dst_p1: (penX + totalWidth, penY + textHeight),
        tex_tl: (0, 0),
        tex_br: (1, 1),
        color: text.background
      )
    )

    // Draw text
    glBindTexture(GLenum(GL_TEXTURE_2D), fontTex)
    var symbols = ContiguousArray<Quad>(
      repeating:
        Quad(
          dst_p0: (0, 0),
          dst_p1: (0, 0),
          tex_tl: (0, 0),
          tex_br: (0, 0),
          color: text.forground
        ), count: text.text.length)

    penX = text.pos.x

    for (i, c) in text.text.utf8.enumerated() {
      let (u0, v0, u1, v1) = glyphUV(c)
      let w = glyphW * text.scale
      let h = glyphH * text.scale
      symbols[i] = Quad(
        dst_p0: (penX, penY),
        dst_p1: (penX + w, penY + h),
        tex_tl: (u0, v0),
        tex_br: (u1, v1),
        color: text.forground
      )
      penX += w + glyphSpacing * text.scale
    }

    guard !symbols.isEmpty else { return }

    unsafe symbols.withUnsafeBytes { buf in
      glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
      unsafe glBufferSubData(
        GLenum(GL_ARRAY_BUFFER), 0, symbols.count * MemoryLayout<Quad>.stride, buf.baseAddress)
    }
    glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(symbols.count))
  }

  public static func drawFrame(_ dim: (height: UInt, width: UInt), _ block: some Block) {

    start = ContinuousClock.now

    glViewport(0, 0, GLsizei(winW), GLsizei(winH))
    glClearColor(0, 0, 0, 1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

    glUseProgram(program)
    glUniform2f(uRes, Float(winW), Float(winH))
    glUniform1i(uTex, 0)

    glBindVertexArray(vao)
    var renderer = Renderer(dim, drawQuad, drawText)
    block.draw(&renderer)

    #if FrameInfo
    let elapsed_text = Text("\(elapsed)", at: (0, 0), scale: 2, forground: .red, background: .black)
    drawText(elapsed_text)
    #endif

    end = ContinuousClock.now
    elapsed = end - start

    _ = unsafe eglSwapBuffers(eglDisplay, eglSurface)
    unsafe wl_surface_damage_buffer(surface, 0, 0, INT32_MAX, INT32_MAX)
    unsafe wl_surface_commit(surface)
  }

  public static func drawFrame(_ dim: (height: UInt32, width: UInt32), _ words: [Text], _ rects: [Quad]) {
    /*
    Still some performace wins to be made here.
    - Send all data to the GPU once perframe instead of for each Quad/Text object.
    - Pre-allocate GPU memory to a max number of quads per draw call.
    - Inline function calls.
    */
    start = ContinuousClock.now

    glViewport(0, 0, GLsizei(winW), GLsizei(winH))
    glClearColor(0, 0, 0, 1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

    glUseProgram(program)
    glUniform2f(uRes, Float(winW), Float(winH))
    glUniform1i(uTex, 0)

    glBindVertexArray(vao)
    // Draw quads
    for quad in rects {
      drawQuad(quad)
    }

    // Draw Text
    for word in words {
      drawText(word)
    }
    #if FrameInfo
    let elapsed_text = Text("\(elapsed)", at: (0, 0), scale: 2, forground: .red, background: .black)
    drawText(elapsed_text)
    #endif

    end = ContinuousClock.now
    elapsed = end - start

    _ = unsafe eglSwapBuffers(eglDisplay, eglSurface)
    unsafe wl_surface_damage_buffer(surface, 0, 0, INT32_MAX, INT32_MAX)
    unsafe wl_surface_commit(surface)
  }

  static var start = ContinuousClock.now
  static var end = ContinuousClock.now
  static var elapsed: Duration = end - start

  static var frameListener = unsafe wl_callback_listener(
    done: { _, callback, _time in
      unsafe wl_callback_destroy(callback)
      print("Callback")
    }
  )

  #if !Toolbar
  static var xdgToplevelListener = unsafe xdg_toplevel_listener(
    configure: xdg_toplevel_configure_cb,
    close: { _, _ in
      state = .exit
    },
    configure_bounds: { _, _, _, _ in },
    wm_capabilities: { _, _, _ in }
  )

  static var keyboard_listener = unsafe wl_keyboard_listener(
    keymap: keyboard_keymap_cb,
    enter: { _, _, _, _, _ in },
    leave: { _, _, _, _ in },
    key: keyboard_key_cb,
    modifiers: { _, _, _, _, _, _, _ in },
    repeat_info: { _, _, _, _ in }
  )
  #endif

  static var seatListener = unsafe wl_seat_listener(
    capabilities: seat_capabilities_cb,
    name: { _, _, _ in }
  )

  static var _wl_seat_interface: wl_interface = unsafe wl_seat_interface
  static var _wl_compositor_interface: wl_interface = unsafe wl_compositor_interface
  static var _xdg_wm_base_interface: wl_interface = unsafe xdg_wm_base_interface
  #if Toolbar
  static var _zwlr_layer_shell_v1_interface: wl_interface = unsafe zwlr_layer_shell_v1_interface
  #endif
  static var registryListener = unsafe wl_registry_listener(global: onGlobal, global_remove: { _, _, _ in })

  static var refresh_rate: Duration = .milliseconds(33)

  public static func setup(_ refresh_rate: Duration = .milliseconds(33)) {
    self.refresh_rate = refresh_rate
    Task {
      unsafe display = wl_display_connect(nil)
      guard unsafe display != nil else {
        state = .error(reason: "Failed to connect to Wayland display.")
        return
      }

      unsafe registry = wl_display_get_registry(display)
      unsafe wl_registry_add_listener(registry, &registryListener, nil)
      unsafe wl_display_roundtrip(display)

      guard unsafe compositor != nil, unsafe wmBase != nil else {
        state = .error(reason: "No compositor or wmBase")
        return
      }

      unsafe surface = wl_compositor_create_surface(compositor)

      #if Toolbar
      guard unsafe layerShell != nil else {
        state = .error(reason: "Layer shell not available")
        return
      }

      unsafe layerSurface = zwlr_layer_shell_v1_get_layer_surface(
        layerShell,
        surface,
        nil,
        2,
        "my_app_namespace"
      )

      unsafe zwlr_layer_surface_v1_set_size(layerSurface, 0, UInt32(toolbar_height))
      unsafe zwlr_layer_surface_v1_set_anchor(
        layerSurface,
        LayerSurfaceAnchor.top.union(.left).union(.right).rawValue
      )
      unsafe zwlr_layer_surface_v1_set_exclusive_zone(layerSurface, Int32(toolbar_height))
      unsafe zwlr_layer_surface_v1_add_listener(layerSurface, &layerSurfaceListener, nil)
      #else
      unsafe xdgSurface = xdg_wm_base_get_xdg_surface(wmBase, surface)
      unsafe xdg_surface_add_listener(xdgSurface, &xdgSurfaceListener, nil)
      unsafe toplevel = xdg_surface_get_toplevel(xdgSurface)
      unsafe xdg_toplevel_add_listener(toplevel, &xdgToplevelListener, nil)
      unsafe xdg_toplevel_set_title(toplevel, "Swift Wayland")
      unsafe wl_surface_damage_buffer(surface, 0, 0, INT32_MAX, INT32_MAX)
      #endif
      unsafe wl_surface_commit(surface)

      do throws(WaylandError) {
        try initEGL()
      } catch let error {
        switch error {
        case .error(let message):
          state = .error(reason: message)
        }
        return
      }
      initGL()

      DispatchQueue.global().async {
        while unsafe wl_display_dispatch(display) != -1 {}
      }

      send(.frame(height: UInt(winH), width: UInt(winW)))
    }
  }

  static var wmBaseListener = unsafe xdg_wm_base_listener(
    ping: { _, base, serial in
      unsafe xdg_wm_base_pong(base, serial)
    }
  )

  #if !Toolbar
  static let xdg_toplevel_configure_cb:
    @convention(c) (
      _ data: UnsafeMutableRawPointer?,
      _ toplevel: OpaquePointer?,
      _ width: Int32,
      _ height: Int32,
      _ states: UnsafeMutablePointer<wl_array>?
    ) -> Void = { data, toplevel, width, height, states in
      if width > 0 && height > 0 {
        winW = UInt32(width)
        winH = UInt32(height)
        if unsafe eglWindow != nil {
          unsafe wl_egl_window_resize(eglWindow, width, height, 0, 0)
        }
      }
    }

  static var xdgSurfaceListener = unsafe xdg_surface_listener(
    configure: { _, surface, serial in
      unsafe xdg_surface_ack_configure(surface, serial)
    }
  )
  #else
  static var layerSurfaceListener = unsafe zwlr_layer_surface_v1_listener(
    configure: { data, _surface, serial, width, height in
      winW = width
      winH = height
      unsafe zwlr_layer_surface_v1_ack_configure(_surface, serial)

      if let eglWin = unsafe eglWindow {
        unsafe wl_egl_window_resize(eglWin, Int32(winW), Int32(winH), 0, 0)
      }

      glViewport(0, 0, GLsizei(winW), GLsizei(winH))
    },
    closed: { data, _surface in
      print("Layer surface closed")
    }
  )
  #endif

  static let onGlobal:
    @convention(c) (
      UnsafeMutableRawPointer?, OpaquePointer?, UInt32, UnsafePointer<CChar>?, UInt32
    ) -> Void = { _, registry, id, interface, version in
      guard let cstr = unsafe interface else { return }
      let iface = unsafe String(cString: cstr)
      switch iface {
      case "wl_compositor":
        unsafe compositor = OpaquePointer(
          wl_registry_bind(registry, id, &_wl_compositor_interface, min(version, 4))
        )
      case "xdg_wm_base":
        unsafe wmBase = OpaquePointer(
          wl_registry_bind(registry, id, &_xdg_wm_base_interface, min(version, 2))
        )
        unsafe xdg_wm_base_add_listener(wmBase, &wmBaseListener, nil)
      case "wl_seat":
        unsafe seat = OpaquePointer(
          wl_registry_bind(registry, id, &_wl_seat_interface, min(version, 5))
        )
        unsafe wl_seat_add_listener(seat, &seatListener, nil)
      #if Toolbar
      case "zwlr_layer_shell_v1":
        unsafe layerShell = OpaquePointer(
          wl_registry_bind(registry, id, &_zwlr_layer_shell_v1_interface, min(version, 4))
        )
        unsafe zwlr_layer_surface_v1_add_listener(layerShell, &layerSurfaceListener, nil)
      #endif
      default:
        ()
      }
    }

  #if !Toolbar
  static let keyboard_keymap_cb:
    @convention(c) (
      UnsafeMutableRawPointer?, OpaquePointer?, UInt32, Int32, UInt32
    ) -> Void = { _, _, _, shared_fd, _ in
      close(shared_fd)
    }

  static let keyboard_key_cb:
    @convention(c) (
      UnsafeMutableRawPointer?, OpaquePointer?, UInt32, UInt32, UInt32, UInt32
    ) -> Void = { _, _, _, _, key, state in
      send(.key(code: UInt(key), state: UInt(state)))
    }
  #endif

  static let seat_capabilities_cb:
    @convention(c) (
      UnsafeMutableRawPointer?, OpaquePointer?, UInt32
    ) -> Void = { _, s, caps in
      #if !Toolbar
      let WL_SEAT_CAPABILITY_KEYBOARD: UInt32 = 1  // bit 0
      if unsafe (caps & WL_SEAT_CAPABILITY_KEYBOARD) != 0 && keyboard == nil {
        unsafe keyboard = wl_seat_get_keyboard(s)
        unsafe wl_keyboard_add_listener(keyboard, &keyboard_listener, nil)
      }
      #endif
    }

  /// I am using this event loop so that I can have async suspenion points in "user space"
  /// This is more of a hack to get around how the wayland-client library works. Because
  /// C doesn't have a notion of async dispatch queues are used which is why we need to call
  /// `wl_display_dispatch` on a background thread. I don't love this but this hack seems to
  /// work well enough for now. Writing our own stand alone client should fix this but I
  /// Don't feel like setting up the shared memory or EGL yet.
  private static var continuation: AsyncStream<WaylandEvent>.Continuation?
  private static var calledOnce = true

  public static func events() -> AsyncStream<WaylandEvent> {
    guard calledOnce else {
      fatalError("Only call events once.")
    }
    calledOnce = true
    Task {
      // Render loop
      while Wayland.state.isRunning {
        try? await Task.sleep(for: refresh_rate)
        send(.frame(height: UInt(winH), width: UInt(winW)))
      }
      continuation?.finish()
    }
    return AsyncStream { cont in continuation = cont }
  }

  private static func send(_ ev: WaylandEvent) {
    continuation?.yield(ev)
  }
}
