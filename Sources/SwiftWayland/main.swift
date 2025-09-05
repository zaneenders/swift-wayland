import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CXDGShell
import Foundation

var egl_display: EGLDisplay?
var egl_context: EGLContext?
var egl_surface: EGLSurface?
var egl_window: OpaquePointer?

var winW: Int32 = 800
var winH: Int32 = 600

let EGL_NO_CONTEXT: EGLContext? = EGLContext(bitPattern: 0)
let EGL_NO_DISPLAY: EGLDisplay? = EGLDisplay(bitPattern: 0)
let EGL_NO_SURFACE: EGLSurface? = EGLSurface(bitPattern: 0)

var display: OpaquePointer!
var registry: OpaquePointer!
var compositor: OpaquePointer!
var wm_base: OpaquePointer!
var seat: OpaquePointer!
var surface: OpaquePointer!
var xdgSurface: OpaquePointer!
var xdgToplevel: OpaquePointer!
var keyboard: OpaquePointer!

var running = true

func wm_base_ping_cb(_ data: UnsafeMutableRawPointer?, _ base: OpaquePointer?, _ serial: UInt32) {
    xdg_wm_base_pong(base, serial)
}

var wmBaseListener = xdg_wm_base_listener(ping: wm_base_ping_cb)

func xdg_surface_configure_cb(_ data: UnsafeMutableRawPointer?, _ xs: OpaquePointer?, _ serial: UInt32) {
    xdg_surface_ack_configure(xs, serial)
}

var xdgSurfaceListener = xdg_surface_listener(configure: xdg_surface_configure_cb)

func xdg_toplevel_configure_cb(
    _ data: UnsafeMutableRawPointer?,
    _ tl: OpaquePointer?,
    _ width: Int32, _ height: Int32,
    _ states: UnsafeMutablePointer<wl_array>?
) {
    if width > 0 && height > 0 {
        winW = width
        winH = height
        if egl_window != nil {
            wl_egl_window_resize(egl_window, winW, winH, 0, 0)
            glBindVertexArray(vao)
            glBindVertexArray(0)
        }
    }
}

func xdg_toplevel_close_cb(_ data: UnsafeMutableRawPointer?, _ tl: OpaquePointer?) {
    running = false
}

var xdgToplevelListener = xdg_toplevel_listener(
    configure: xdg_toplevel_configure_cb,
    close: xdg_toplevel_close_cb,
    configure_bounds: { _, _, _, _ in },
    wm_capabilities: { _, _, _ in }
)

func keyboard_keymap_cb(
    data: UnsafeMutableRawPointer?, kb: OpaquePointer?, format: UInt32, shared_fd: Int32,
    size: UInt32
) { close(shared_fd) }

func keyboard_enter_cb(
    data: UnsafeMutableRawPointer?, kb: OpaquePointer?, serial: UInt32,
    surface: OpaquePointer?, keys: UnsafeMutablePointer<wl_array>?
) {}

func keyboard_leave_cb(
    data: UnsafeMutableRawPointer?, kb: OpaquePointer?, serial: UInt32,
    surface: OpaquePointer?
) {}

func keyboard_key_cb(
    data: UnsafeMutableRawPointer?, kb: OpaquePointer?, serial: UInt32, time: UInt32, key: UInt32,
    state: UInt32
) {
    let WL_KEYBOARD_KEY_STATE_PRESSED: UInt32 = 1
    let KEY_ESC: UInt32 = 1
    if state == WL_KEYBOARD_KEY_STATE_PRESSED {
        if key == KEY_ESC {
            fputs("ESC pressed, exiting.\n", stderr)
            running = false
        } else {
            fputs("Key pressed: \(key)\n", stderr)
        }
    }
}

func keyboard_modifiers_cb(
    data: UnsafeMutableRawPointer?, kb: OpaquePointer?, serial: UInt32, mods_depressed: UInt32,
    mods_latched: UInt32, mods_locked: UInt32, group: UInt32
) {}

func keyboard_repeat_info_cb(
    data: UnsafeMutableRawPointer?, kb: OpaquePointer?, rate: Int32, delay: Int32
) {}

var keyboard_listener = wl_keyboard_listener(
    keymap: keyboard_keymap_cb,
    enter: keyboard_enter_cb,
    leave: keyboard_leave_cb,
    key: keyboard_key_cb,
    modifiers: keyboard_modifiers_cb,
    repeat_info: keyboard_repeat_info_cb
)

func seat_capabilities_cb(data: UnsafeMutableRawPointer?, s: OpaquePointer?, caps: UInt32) {
    let WL_SEAT_CAPABILITY_KEYBOARD: UInt32 = 1  // bit 0
    if (caps & WL_SEAT_CAPABILITY_KEYBOARD) != 0 && keyboard == nil {
        keyboard = wl_seat_get_keyboard(s)
        wl_keyboard_add_listener(keyboard, &keyboard_listener, nil)
    } else if (caps & WL_SEAT_CAPABILITY_KEYBOARD) == 0 && keyboard != nil {
        wl_keyboard_destroy(keyboard)
        keyboard = nil
    }
}

func seat_name_cb(data: UnsafeMutableRawPointer?, s: OpaquePointer?, name: UnsafePointer<Int8>?) {}

var seatListener = wl_seat_listener(capabilities: seat_capabilities_cb, name: seat_name_cb)

var _wl_compositor_interface: wl_interface = wl_compositor_interface
var _xdg_wm_base_interface: wl_interface = xdg_wm_base_interface
var _wl_seat_interface: wl_interface = wl_seat_interface

var v: UInt32 = UInt32.max

func onGlobal(
    _ data: UnsafeMutableRawPointer?,
    _ registry: OpaquePointer?,
    _ name: UInt32,
    _ interface: UnsafePointer<CChar>?,
    _ version: UInt32
) {
    guard let cstr = interface else { return }
    switch String(cString: cstr) {
    case "wl_compositor":
        v = min(version, 4)
        compositor = OpaquePointer(wl_registry_bind(registry, name, &_wl_compositor_interface, v))
    case "xdg_wm_base":
        v = min(version, 2)
        wm_base = OpaquePointer(wl_registry_bind(registry, name, &_xdg_wm_base_interface, v))
        xdg_wm_base_add_listener(wm_base, &wmBaseListener, nil)
    case "wl_seat":
        v = min(version, 5)
        seat = OpaquePointer(wl_registry_bind(registry, name, &_wl_seat_interface, v))
    default:
        break
    }
}

func initEGL(_ wlSurface: OpaquePointer) {
    egl_display = eglGetDisplay(EGLNativeDisplayType(display))
    guard egl_display != nil else { fatalError("eglGetDisplay failed") }
    guard eglInitialize(egl_display, nil, nil) == EGL_TRUE else { fatalError("eglInitialize failed") }

    var cfg: EGLConfig? = nil
    var num: EGLint = 0
    var attrs: [EGLint] = [
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
        EGL_NONE,
    ]
    attrs.withUnsafeMutableBufferPointer { p in
        _ = eglChooseConfig(egl_display, p.baseAddress, &cfg, 1, &num)
    }
    guard num > 0 else { fatalError("eglChooseConfig failed") }
    guard eglBindAPI(EGLenum(EGL_OPENGL_ES_API)) == EGL_TRUE else { fatalError("eglBindAPI failed") }

    var ctxAttrs: [EGLint] = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE]
    egl_context = ctxAttrs.withUnsafeMutableBufferPointer { p in
        eglCreateContext(egl_display, cfg, EGL_NO_CONTEXT, p.baseAddress)
    }
    guard egl_context != EGL_NO_CONTEXT else { fatalError("eglCreateContext failed") }

    egl_window = wl_egl_window_create(wlSurface, winW, winH)
    guard egl_window != nil else { fatalError("wl_egl_window_create failed") }

    egl_surface = eglCreateWindowSurface(egl_display, cfg, EGLNativeWindowType(bitPattern: egl_window), nil)
    guard egl_surface != EGL_NO_SURFACE else { fatalError("eglCreateWindowSurface failed") }

    guard eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context) == EGL_TRUE else {
        fatalError("eglMakeCurrent failed")
    }
    _ = eglSwapInterval(egl_display, 1)
}

func compileShader(_ type: GLenum, _ src: String) -> GLuint {
    let s = glCreateShader(type)
    src.withCString { cstr in
        var p: UnsafePointer<GLchar>? = UnsafePointer(cstr)
        var len = GLint(src.utf8.count)
        glShaderSource(s, 1, &p, &len)
    }
    glCompileShader(s)
    var ok: GLint = 0
    glGetShaderiv(s, EGLenum(GL_COMPILE_STATUS), &ok)
    if ok == 0 {
        var logLen: GLint = 0
        glGetShaderiv(s, EGLenum(GL_INFO_LOG_LENGTH), &logLen)
        var buf = [GLchar](repeating: 0, count: Int(logLen))
        glGetShaderInfoLog(s, logLen, nil, &buf)
        let msg = String(cString: buf)
        fatalError("Shader compile error: \(msg)")
    }
    return s
}

func loadText(resource name: String) -> String {
    let url = Bundle.module.url(forResource: name, withExtension: nil)!
    let data = try! Data(contentsOf: url)
    return String(decoding: data, as: UTF8.self)
}

func linkProgram(vs: GLuint, fs: GLuint) -> GLuint {
    let p = glCreateProgram()
    glAttachShader(p, vs)
    glAttachShader(p, fs)
    glLinkProgram(p)
    var ok: GLint = 0
    glGetProgramiv(p, GLenum(GL_LINK_STATUS), &ok)
    if ok == 0 {
        var logLen: GLint = 0
        glGetProgramiv(p, GLenum(GL_INFO_LOG_LENGTH), &logLen)
        let buf = UnsafeMutablePointer<GLchar>.allocate(capacity: Int(logLen))
        defer { buf.deallocate() }
        glGetProgramInfoLog(p, GLsizei(logLen), nil, buf)
        let msg = String(cString: buf)
        fatalError("Program link error: \(msg)")
    }
    glDeleteShader(vs)
    glDeleteShader(fs)
    return p
}

let GLYPH_W = 5
let GLYPH_H = 7
let GLYPH_SPACING = 1
let FIRST_CHAR: UInt8 = 32
let LAST_CHAR: UInt8 = 126
let NUM_CHARS = Int(LAST_CHAR - FIRST_CHAR + 1)
var program: GLuint = 0
var vao: GLuint = 0
var fontTex: GLuint = 0
var whiteTex: GLuint = 0
var quadVBO: GLuint = 0
var instanceVBO: GLuint = 0
var atlasW = 0
var atlasH = 0

struct Glyph { var rows: [String] = Array(repeating: "", count: GLYPH_H) }
var font5x7 = Array(repeating: Glyph(), count: 128)

struct Color { var r, g, b, a: GLfloat }
struct RectInstance {
    var dst_p0: (GLfloat, GLfloat)
    var dst_p1: (GLfloat, GLfloat)
    var tex_tl: (GLfloat, GLfloat)
    var tex_br: (GLfloat, GLfloat)
    var color: Color
}

let quadVerts: [GLfloat] = [
    -1.0, 1.0,  // TL
    1.0, 1.0,  // TR
    -1.0, -1.0,  // BL
    1.0, -1.0,  // BR
]

func initGL() {
    let vs = compileShader(GLenum(GL_VERTEX_SHADER), loadText(resource: "vertex.glsl"))
    let fs = compileShader(GLenum(GL_FRAGMENT_SHADER), loadText(resource: "fragment.glsl"))
    program = linkProgram(vs: vs, fs: fs)

    glEnable(GLenum(GL_BLEND))
    glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    glGenVertexArrays(1, &vao)
    glBindVertexArray(vao)

    glGenBuffers(1, &quadVBO)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), quadVBO)
    quadVerts.withUnsafeBytes { ptr in
        glBufferData(GLenum(GL_ARRAY_BUFFER), ptr.count, ptr.baseAddress, GLenum(GL_STATIC_DRAW))
    }
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(
        0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 2 * GLint(MemoryLayout<GLfloat>.size),
        UnsafeRawPointer(bitPattern: 0))

    glGenBuffers(1, &instanceVBO)
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
    glBufferData(GLenum(GL_ARRAY_BUFFER), 4000 * MemoryLayout<RectInstance>.stride, nil, GLenum(GL_DYNAMIC_DRAW))

    let stride = GLsizei(MemoryLayout<RectInstance>.stride)
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: 0 + 0))
    glVertexAttribDivisor(1, 1)

    let off_dst_p1 = MemoryLayout<(GLfloat, GLfloat)>.stride
    glEnableVertexAttribArray(2)
    glVertexAttribPointer(2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_dst_p1))
    glVertexAttribDivisor(2, 1)

    let off_tex_tl = off_dst_p1 + MemoryLayout<(GLfloat, GLfloat)>.stride
    glEnableVertexAttribArray(3)
    glVertexAttribPointer(3, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_tl))
    glVertexAttribDivisor(3, 1)

    let off_tex_br = off_tex_tl + MemoryLayout<(GLfloat, GLfloat)>.stride
    glEnableVertexAttribArray(4)
    glVertexAttribPointer(4, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_br))
    glVertexAttribDivisor(4, 1)

    let off_color = off_tex_br + MemoryLayout<(GLfloat, GLfloat)>.stride
    glEnableVertexAttribArray(5)
    glVertexAttribPointer(5, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_color))
    glVertexAttribDivisor(5, 1)

    glGenTextures(1, &whiteTex)
    glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
    let px: [UInt8] = [255, 255, 255, 255]
    px.withUnsafeBytes { p in
        glTexImage2D(
            GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA), 1, 1, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), p.baseAddress)
    }
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)

    initFont()
    createFontAtlas()
}

func initFont() {
    func set(_ ch: Character, _ rows: [String]) {
        let i = Int(ch.unicodeScalars.first!.value)
        font5x7[i] = Glyph(rows: rows)
    }
    set("S", ["01110", "10001", "10000", "01110", "00001", "10001", "01110"])
    set("c", ["00000", "00000", "01110", "10000", "10000", "10001", "01110"])
    set("r", ["00000", "00000", "10110", "11001", "10000", "10000", "10000"])
    set("i", ["00100", "00000", "01100", "00100", "00100", "00100", "01110"])
    set("b", ["10000", "10000", "11110", "10001", "10001", "10001", "11110"])
    set("e", ["00000", "00000", "01110", "10001", "11111", "10000", "01110"])
}

func createFontAtlas() {
    atlasW = NUM_CHARS * (GLYPH_W + GLYPH_SPACING)
    atlasH = GLYPH_H
    let pixelsCount = atlasW * atlasH * 4
    let img = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelsCount)
    img.initialize(repeating: 0, count: pixelsCount)
    defer { img.deallocate() }

    for c in Int(FIRST_CHAR)...Int(LAST_CHAR) {
        let g = font5x7[c]
        let xoff = (c - Int(FIRST_CHAR)) * (GLYPH_W + GLYPH_SPACING)
        if !g.rows[0].isEmpty {
            for y in 0..<GLYPH_H {
                let row = Array(g.rows[y])
                for x in 0..<GLYPH_W {
                    let bit = row[x] == "1"
                    let idx = (y * atlasW + xoff + x) * 4
                    img[idx + 0] = 255
                    img[idx + 1] = 255
                    img[idx + 2] = 255
                    img[idx + 3] = bit ? 255 : 0
                }
            }
        }
    }

    glGenTextures(1, &fontTex)
    glBindTexture(GLenum(GL_TEXTURE_2D), fontTex)
    glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
    glTexImage2D(
        GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA8), GLsizei(atlasW), GLsizei(atlasH), 0, GLenum(GL_RGBA),
        GLenum(GL_UNSIGNED_BYTE), img)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
}

func glyphUV(_ c: UInt8) -> (GLfloat, GLfloat, GLfloat, GLfloat) {
    var ch = c
    if ch < FIRST_CHAR || ch > LAST_CHAR { ch = 32 }
    let idx = Int(ch - FIRST_CHAR)
    let xoff = idx * (GLYPH_W + GLYPH_SPACING)
    let u0 = GLfloat(xoff) / GLfloat(atlasW)
    let u1 = GLfloat(xoff + GLYPH_W) / GLfloat(atlasW)
    let v0 = GLfloat(1.0) - GLfloat(GLYPH_H) / GLfloat(atlasH)
    let v1 = GLfloat(1.0)
    return (u0, v0, u1, v1)
}

func drawFrame() {
    glViewport(0, 0, GLsizei(winW), GLsizei(winH))
    glClearColor(0, 0, 0, 1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

    glUseProgram(program)
    let uRes = glGetUniformLocation(program, "uRes")
    let uTex = glGetUniformLocation(program, "uTex")
    glUniform2f(uRes, GLfloat(winW), GLfloat(winH))
    glUniform1i(uTex, 0)

    glBindVertexArray(vao)
    var rects: [RectInstance] = Array(
        repeating: RectInstance(
            dst_p0: (0, 0), dst_p1: (0, 0), tex_tl: (0, 0), tex_br: (0, 0), color: Color(r: 1, g: 1, b: 1, a: 1)
        ), count: 128)
    var n = 0

    rects[n] = RectInstance(
        dst_p0: (0, 0), dst_p1: (GLfloat(winW), 200),
        tex_tl: (0, 0), tex_br: (1, 1), color: Color(r: 0, g: 1, b: 1, a: 1)
    )
    n += 1

    rects[n] = RectInstance(
        dst_p0: (GLfloat(winW), GLfloat(winH - 200)), dst_p1: (0, GLfloat(winH)),
        tex_tl: (0, 0), tex_br: (1, 1), color: Color(r: 0.5, g: 1, b: 0.5, a: 1)
    )
    n += 1

    glActiveTexture(GLenum(GL_TEXTURE0))
    glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
    rects.withUnsafeBytes { buf in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, n * MemoryLayout<RectInstance>.stride, buf.baseAddress)
    }
    glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(n))

    glBindTexture(GLenum(GL_TEXTURE_2D), fontTex)

    let msg = Array("Scribe".utf8)

    let scale: Float = 12.0
    var textW: Float = 0
    for _ in msg { textW += Float(GLYPH_W) * scale + Float(GLYPH_SPACING) * scale }
    textW -= Float(GLYPH_SPACING) * scale
    let textH = Float(GLYPH_H) * scale
    var penX = (Float(winW) - textW) * 0.5
    let penY = (Float(winH) - textH) * 0.5

    var tcount = 0
    for c in msg {
        if tcount >= 64 { break }
        let (u0, v0, u1, v1) = glyphUV(c)
        let w = Float(GLYPH_W) * scale
        let h = Float(GLYPH_H) * scale
        rects[tcount] = RectInstance(
            dst_p0: (GLfloat(penX), GLfloat(penY)),
            dst_p1: (GLfloat(penX + w), GLfloat(penY + h)),
            tex_tl: (u0, v0), tex_br: (u1, v1),
            color: Color(r: 1, g: 1, b: 1, a: 1)
        )
        tcount += 1
        penX += w + Float(GLYPH_SPACING) * scale
    }
    rects.withUnsafeBytes { buf in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, tcount * MemoryLayout<RectInstance>.stride, buf.baseAddress)
    }
    glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(tcount))

    _ = eglSwapBuffers(egl_display, egl_surface)
}

private func onGlobalRemove(_ data: UnsafeMutableRawPointer?, _ registry: OpaquePointer?, _ name: UInt32) {}

private var registryListener = wl_registry_listener(global: onGlobal, global_remove: onGlobalRemove)

display = wl_display_connect(nil)
guard display != nil else {
    fputs("Failed to connect to Wayland display.\n", stderr)
    exit(1)
}

registry = wl_display_get_registry(display)
wl_registry_add_listener(registry, &registryListener, nil)
wl_display_roundtrip(display)

if seat != nil { wl_seat_add_listener(seat, &seatListener, nil) }
guard compositor != nil && wm_base != nil else {
    fputs("Compositor or xdg_wm_base not available.\n", stderr)
    exit(1)
}

surface = wl_compositor_create_surface(compositor)
xdgSurface = xdg_wm_base_get_xdg_surface(wm_base, surface)
xdg_surface_add_listener(xdgSurface, &xdgSurfaceListener, nil)

xdgToplevel = xdg_surface_get_toplevel(xdgSurface)
xdg_toplevel_add_listener(xdgToplevel, &xdgToplevelListener, nil)
xdg_toplevel_set_title(xdgToplevel, "Swift Wayland")
wl_surface_commit(surface)

initEGL(surface)
initGL()

while running && wl_display_dispatch(display) != -1 {
    drawFrame()
}
