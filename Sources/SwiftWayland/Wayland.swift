import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CXDGShell
import Foundation

/// There is alot of global state here to setup and conform to Wayland's patterns.
/// Their might be better ways to abstract this and clean it up a bit. But it's
/// working for now.
@MainActor
internal enum Wayland {

    @MainActor
    private struct Glyph {
        var rows: [String] = Array(repeating: "", count: glyphH)
    }

    struct Color { var r, g, b, a: GLfloat }

    struct Quad {
        var dst_p0: (GLfloat, GLfloat)
        var dst_p1: (GLfloat, GLfloat)
        var tex_tl: (GLfloat, GLfloat)
        var tex_br: (GLfloat, GLfloat)
        var color: Color
    }

    static let quadVerts: [GLfloat] = [
        -1.0, 1.0,  // TL
        1.0, 1.0,  // TR
        -1.0, -1.0,  // BL
        1.0, -1.0,  // BR
    ]

    enum State {
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

    static var state: State = .running

    static let glyphW = 5
    static let glyphH = 7
    static let glyphSpacing = 1
    static let firstChar: UInt8 = 32
    static let lastChar: UInt8 = 126
    static let charCount = Int(lastChar - firstChar + 1)

    static var winW: Int32 = 800
    static var winH: Int32 = 600

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

    static var atlasW = 0
    static var atlasH = 0
    private static var font5x7 = Array(repeating: Glyph(), count: 128)

    nonisolated(unsafe) static var display: OpaquePointer!
    static var registry: OpaquePointer!
    static var compositor: OpaquePointer!
    static var wmBase: OpaquePointer!
    static var seat: OpaquePointer!
    static var surface: OpaquePointer!
    static var xdgSurface: OpaquePointer!
    static var toplevel: OpaquePointer!
    static var keyboard: OpaquePointer!

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

        unsafe eglWindow = wl_egl_window_create(surface, winW, winH)
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
            0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 2 * GLint(MemoryLayout<GLfloat>.size),
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

        let off_dst_p1 = MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(2)
        unsafe glVertexAttribPointer(
            2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_dst_p1))
        glVertexAttribDivisor(2, 1)

        let off_tex_tl = off_dst_p1 + MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(3)
        unsafe glVertexAttribPointer(
            3, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_tl))
        glVertexAttribDivisor(3, 1)

        let off_tex_br = off_tex_tl + MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(4)
        unsafe glVertexAttribPointer(
            4, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_br))
        glVertexAttribDivisor(4, 1)

        let off_color = off_tex_br + MemoryLayout<(GLfloat, GLfloat)>.stride
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

        initFont()
        createFontAtlas()
    }

    static func initFont() {
        func set(_ ch: Character, _ rows: [String]) {
            let i = Int(ch.unicodeScalars.first!.value)
            font5x7[i] = Glyph(rows: rows)
        }
        set(" ", ["00000", "00000", "00000", "00000", "00000", "00000", "00000"])
        set("!", ["00100", "00100", "00100", "00100", "00100", "00000", "00100"])
        set("\"", ["01010", "01010", "01010", "00000", "00000", "00000", "00000"])
        set("#", ["01010", "01010", "11111", "01010", "11111", "01010", "01010"])
        set("$", ["00100", "01111", "10100", "01110", "00101", "11110", "00100"])
        set("%", ["11001", "11010", "00100", "01000", "10110", "00110", "10011"])
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
    }

    static func createFontAtlas() {
        atlasW = charCount * (glyphW + glyphSpacing)
        atlasH = glyphH
        let pixelsCount = atlasW * atlasH * 4
        let img = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelsCount)
        unsafe img.initialize(repeating: 0, count: pixelsCount)
        defer { unsafe img.deallocate() }

        for c in Int(firstChar)...Int(lastChar) {
            let g = font5x7[c]
            let xoff = (c - Int(firstChar)) * (glyphW + glyphSpacing)
            if !g.rows[0].isEmpty {
                for y in 0..<glyphH {
                    let row = Array(g.rows[y])
                    for x in 0..<glyphW {
                        let bit = row[x] == "1"
                        let idx = (y * atlasW + xoff + x) * 4
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

    static func glyphUV(_ c: UInt8) -> (GLfloat, GLfloat, GLfloat, GLfloat) {
        var ch = c
        if ch < firstChar || ch > lastChar { ch = 32 }
        let idx = Int(ch - firstChar)
        let xoff = idx * (glyphW + glyphSpacing)
        let u0 = GLfloat(xoff) / GLfloat(atlasW)
        let u1 = GLfloat(xoff + glyphW) / GLfloat(atlasW)
        let v0 = GLfloat(1.0) - GLfloat(glyphH) / GLfloat(atlasH)
        let v1 = GLfloat(1.0)
        return (u0, v0, u1, v1)
    }

    static func drawFrame(_ word: String, count: Int) {
        glViewport(0, 0, GLsizei(winW), GLsizei(winH))
        glClearColor(0, 0, 0, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glUseProgram(program)
        let uRes = unsafe glGetUniformLocation(program, "uRes")
        let uTex = unsafe glGetUniformLocation(program, "uTex")
        glUniform2f(uRes, GLfloat(winW), GLfloat(winH))
        glUniform1i(uTex, 0)

        glBindVertexArray(vao)
        var rects: [Quad] = Array(
            repeating: Quad(
                dst_p0: (0, 0), dst_p1: (0, 0), tex_tl: (0, 0), tex_br: (0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)
            ), count: 128)
        var n = 0

        rects[n] = Quad(
            dst_p0: (0, 0), dst_p1: (GLfloat(winW), 200),
            tex_tl: (0, 0), tex_br: (1, 1), color: Color(r: 0, g: 1, b: 1, a: 1)
        )
        n += 1

        rects[n] = Quad(
            dst_p0: (GLfloat(winW), GLfloat(winH - 200)), dst_p1: (0, GLfloat(winH)),
            tex_tl: (0, 0), tex_br: (1, 1), color: Color(r: 0.5, g: 1, b: 0.5, a: 1)
        )
        n += 1

        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
        unsafe rects.withUnsafeBytes { buf in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
            unsafe glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, n * MemoryLayout<Quad>.stride, buf.baseAddress)
        }
        glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(n))

        glBindTexture(GLenum(GL_TEXTURE_2D), fontTex)

        let msg = Array(word.utf8)

        let scale: Float = 12.0
        var textW: Float = 0
        for _ in msg { textW += Float(glyphW) * scale + Float(glyphSpacing) * scale }
        textW -= Float(glyphSpacing) * scale
        var textH = Float(glyphH) * scale
        var penX = (Float(winW) - textW) * 0.5
        var penY = (Float(winH) - textH) * 0.5 - 50

        var tcount = 0
        for c in msg {
            if tcount >= 64 { break }
            let (u0, v0, u1, v1) = glyphUV(c)
            let w = Float(glyphW) * scale
            let h = Float(glyphH) * scale
            rects[tcount] = Quad(
                dst_p0: (GLfloat(penX), GLfloat(penY)),
                dst_p1: (GLfloat(penX + w), GLfloat(penY + h)),
                tex_tl: (u0, v0), tex_br: (u1, v1),
                color: Color(r: 1, g: 1, b: 1, a: 1)
            )
            tcount += 1
            penX += w + Float(glyphSpacing) * scale
        }
        unsafe rects.withUnsafeBytes { buf in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
            unsafe glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, tcount * MemoryLayout<Quad>.stride, buf.baseAddress)
        }
        glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(tcount))

        let asciiStart = 32
        let asciiEnd = 126
        let asciiRange = asciiEnd - asciiStart + 1
        let code = asciiStart + (count % asciiRange)
        var cmsg = Array(Character(" ").utf8)
        if let scalar = UnicodeScalar(code) {
            cmsg = Array(Character(scalar).utf8)
        }

        textW = 0
        for _ in cmsg { textW += Float(glyphW) * scale + Float(glyphSpacing) * scale }
        textW -= Float(glyphSpacing) * scale
        textH = Float(glyphH) * scale
        penX = (Float(winW) - textW) * 0.5
        penY = (Float(winH) - textH) * 0.5 + 50

        tcount = 0
        for c in cmsg {
            if tcount >= 64 { break }
            let (u0, v0, u1, v1) = glyphUV(c)
            let w = Float(glyphW) * scale
            let h = Float(glyphH) * scale
            rects[tcount] = Quad(
                dst_p0: (GLfloat(penX), GLfloat(penY)),
                dst_p1: (GLfloat(penX + w), GLfloat(penY + h)),
                tex_tl: (u0, v0), tex_br: (u1, v1),
                color: Color(r: 1, g: 1, b: 1, a: 1)
            )
            tcount += 1
            penX += w + Float(glyphSpacing) * scale
        }
        unsafe rects.withUnsafeBytes { buf in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
            unsafe glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, tcount * MemoryLayout<Quad>.stride, buf.baseAddress)
        }
        glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(tcount))

        _ = unsafe eglSwapBuffers(eglDisplay, eglSurface)

        unsafe wl_surface_damage_buffer(surface, 0, 0, INT32_MAX, INT32_MAX)
        unsafe wl_surface_commit(surface)

        end = ContinuousClock.now
        // print(#function, end - start)
        start = ContinuousClock.now
    }

    static var start = ContinuousClock.now
    static var end = ContinuousClock.now

    static var frameListener = unsafe wl_callback_listener(
        done: { _, callback, _time in
            unsafe wl_callback_destroy(callback)
            print("Callback")
        }
    )

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

    static var seatListener = unsafe wl_seat_listener(
        capabilities: seat_capabilities_cb,
        name: { _, _, _ in }
    )

    static var _wl_seat_interface: wl_interface = unsafe wl_seat_interface
    static var _wl_compositor_interface: wl_interface = unsafe wl_compositor_interface
    static var _xdg_wm_base_interface: wl_interface = unsafe xdg_wm_base_interface
    static var registryListener = unsafe wl_registry_listener(global: onGlobal, global_remove: { _, _, _ in })

    static func setup() {
        Task {
            unsafe display = wl_display_connect(nil)
            guard unsafe display != nil else {
                state = .error(reason: "Failed to connect to Wayland display.")
                return
            }
            unsafe registry = wl_display_get_registry(display)
            unsafe wl_registry_add_listener(registry, &registryListener, nil)
            unsafe wl_display_roundtrip(display)
            guard unsafe compositor != nil, unsafe wmBase != nil && surface == nil else {
                state = .error(reason: "No compositor, wmBase")
                return
            }

            unsafe surface = wl_compositor_create_surface(compositor)
            unsafe xdgSurface = xdg_wm_base_get_xdg_surface(wmBase, surface)
            unsafe xdg_surface_add_listener(xdgSurface, &xdgSurfaceListener, nil)
            unsafe toplevel = xdg_surface_get_toplevel(xdgSurface)
            unsafe xdg_toplevel_add_listener(toplevel, &xdgToplevelListener, nil)
            unsafe xdg_toplevel_set_title(toplevel, "Swift Wayland")
            unsafe wl_surface_damage_buffer(surface, 0, 0, INT32_MAX, INT32_MAX)
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
            WaylandEvents.send(.frame)
        }
    }

    static var wmBaseListener = unsafe xdg_wm_base_listener(
        ping: { _, base, serial in
            unsafe xdg_wm_base_pong(base, serial)
        }
    )

    static var xdgSurfaceListener = unsafe xdg_surface_listener(
        configure: { _, surface, serial in
            unsafe xdg_surface_ack_configure(surface, serial)
        }
    )

    static let xdg_toplevel_configure_cb:
        @convention(c) (
            _ data: UnsafeMutableRawPointer?,
            _ toplevel: OpaquePointer?,
            _ width: Int32,
            _ height: Int32,
            _ states: UnsafeMutablePointer<wl_array>?
        ) -> Void = { data, toplevel, width, height, states in
            if width > 0 && height > 0 {
                winW = width
                winH = height
                if unsafe eglWindow != nil {
                    unsafe wl_egl_window_resize(eglWindow, winW, winH, 0, 0)
                }
            }
        }

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
            default:
                ()
            }
        }

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
            WaylandEvents.send(.key(code: key, state: state))
        }

    static let seat_capabilities_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32
        ) -> Void = { _, s, caps in
            let WL_SEAT_CAPABILITY_KEYBOARD: UInt32 = 1  // bit 0
            if unsafe (caps & WL_SEAT_CAPABILITY_KEYBOARD) != 0 && keyboard == nil {
                unsafe keyboard = wl_seat_get_keyboard(s)
                unsafe wl_keyboard_add_listener(keyboard, &keyboard_listener, nil)
            }
        }
}

enum WaylandEvent {
    case key(code: UInt32, state: UInt32)
    case frame
}

/// I am using this event loop so that I can have async suspenion points in "user space"
/// This is more of a hack to get around how the wayland-client library works. Because
/// C doesn't have a notion of async dispatch queues are used which is why we need to call
/// `wl_display_dispatch` on a background thread. I don't love this but this hack seems to
/// work well enough for now. Writing our own stand alone client should fix this but I
/// Don't feel like setting up the shared memory or EGL yet.
@MainActor
enum WaylandEvents {
    private static var continuation: AsyncStream<WaylandEvent>.Continuation?
    private static var calledOnce = true

    static func events() -> AsyncStream<WaylandEvent> {
        guard calledOnce else {
            fatalError("Only call events once.")
        }
        calledOnce = true
        Task {
            // Render loop
            while Wayland.state.isRunning {
                try? await Task.sleep(for: .milliseconds(33))
                WaylandEvents.send(.frame)
            }
            continuation?.finish()
        }
        return AsyncStream { cont in continuation = cont }
    }

    static func send(_ ev: WaylandEvent) {
        continuation?.yield(ev)
    }
}

enum WaylandError: Error {
    case error(message: String)
}
