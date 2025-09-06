import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CXDGShell
import Foundation

@MainActor
internal enum Wayland {
    static func setup() {
        Task {
            display = wl_display_connect(nil)
            guard display != nil else {
                print("Failed to connect to Wayland display.")
                exit(1)
            }
            registry = wl_display_get_registry(display)
            wl_registry_add_listener(registry, &registryListener, nil)
            wl_display_roundtrip(display)
            guard compositor != nil, wmBase != nil && surface == nil else {
                print("No compositor, wmBase")
                return
            }

            surface = wl_compositor_create_surface(compositor)
            xdgSurface = xdg_wm_base_get_xdg_surface(wmBase, surface)
            xdg_surface_add_listener(xdgSurface, &xdgSurfaceListener, nil)
            toplevel = xdg_surface_get_toplevel(xdgSurface)
            xdg_toplevel_add_listener(toplevel, &xdgToplevelListener, nil)
            xdg_toplevel_set_title(toplevel, "Swift Wayland")
            wl_surface_commit(surface)
            wl_display_roundtrip(display)

            eglDisplay = eglGetDisplay(EGLNativeDisplayType(display))
            guard eglDisplay != nil else { fatalError("eglGetDisplay failed") }
            guard eglInitialize(eglDisplay, nil, nil) == EGL_TRUE else { fatalError("eglInitialize failed") }

            guard eglBindAPI(EGLenum(EGL_OPENGL_ES_API)) == EGL_TRUE else { fatalError("eglBindAPI failed") }

            var cfg: EGLConfig?
            var num: EGLint = 0
            var attrs: [EGLint] = [
                EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
                EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
                EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
                EGL_NONE,
            ]
            attrs.withUnsafeMutableBufferPointer { p in
                _ = eglChooseConfig(eglDisplay, p.baseAddress, &cfg, 1, &num)
            }
            guard num > 0, let cfg else { fatalError("eglChooseConfig failed") }

            var ctxAttrs: [EGLint] = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE]
            eglContext = ctxAttrs.withUnsafeMutableBufferPointer { p in
                eglCreateContext(eglDisplay, cfg, EGL_NO_CONTEXT, p.baseAddress)
            }
            guard eglContext != EGL_NO_CONTEXT else { fatalError("eglCreateContext failed") }

            eglWindow = wl_egl_window_create(surface, winW, winH)
            guard eglWindow != nil else { fatalError("wl_egl_window_create failed") }

            eglSurface = eglCreateWindowSurface(eglDisplay, cfg, EGLNativeWindowType(bitPattern: eglWindow), nil)
            guard eglSurface != EGL_NO_SURFACE else { fatalError("eglCreateWindowSurface failed") }

            guard eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext) == EGL_TRUE else {
                fatalError("eglMakeCurrent failed")
            }

            _ = eglSwapInterval(eglDisplay, 1)
            initGL()

            DispatchQueue.global().async {
                while wl_display_dispatch(display) != -1 {}
            }
            WaylandEvents.send(.frame)
        }
    }

    static func drawFrame(_ word: String, count: Int) {
        glViewport(0, 0, GLsizei(winW), GLsizei(winH))
        glClearColor(0, 0, 0, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glUseProgram(program)
        let uRes = glGetUniformLocation(program, "uRes")
        let uTex = glGetUniformLocation(program, "uTex")
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
        rects.withUnsafeBytes { buf in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
            glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, n * MemoryLayout<Quad>.stride, buf.baseAddress)
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
        rects.withUnsafeBytes { buf in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
            glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, tcount * MemoryLayout<Quad>.stride, buf.baseAddress)
        }
        glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(tcount))

        let cmsg = Array("\(count)".utf8)

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
        rects.withUnsafeBytes { buf in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), instanceVBO)
            glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, tcount * MemoryLayout<Quad>.stride, buf.baseAddress)
        }
        glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, GLsizei(tcount))

        _ = eglSwapBuffers(eglDisplay, eglSurface)
        end = ContinuousClock.now
        // print(#function, end - start)
        start = ContinuousClock.now
        scheduleNextFrame()
    }

    static func compileShader(_ type: GLenum, _ src: String) -> GLuint {
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
            var buf = [UInt8](repeating: 0, count: Int(logLen))
            glGetShaderInfoLog(s, logLen, nil, &buf)
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

    static let quadVerts: [GLfloat] = [
        -1.0, 1.0,  // TL
        1.0, 1.0,  // TR
        -1.0, -1.0,  // BL
        1.0, -1.0,  // BR
    ]
    struct Color { var r, g, b, a: GLfloat }
    struct Quad {
        var dst_p0: (GLfloat, GLfloat)
        var dst_p1: (GLfloat, GLfloat)
        var tex_tl: (GLfloat, GLfloat)
        var tex_br: (GLfloat, GLfloat)
        var color: Color
    }

    static let glyphW = 5
    static let glyphH = 7
    static let glyphSpacing = 1
    static let firstChar: UInt8 = 32
    static let lastChar: UInt8 = 126
    static let charCount = Int(lastChar - firstChar + 1)

    @MainActor
    private struct Glyph {
        var rows: [String] = Array(repeating: "", count: glyphH)
    }

    static var program: GLuint = 0
    static var vao: GLuint = 0
    static var fontTex: GLuint = 0
    static var whiteTex: GLuint = 0
    static var quadVBO: GLuint = 0
    static var instanceVBO: GLuint = 0

    static func initGL() {
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
        glBufferData(
            GLenum(GL_ARRAY_BUFFER), 4000 * MemoryLayout<Quad>.stride, nil, GLenum(GL_DYNAMIC_DRAW))

        let stride = GLsizei(MemoryLayout<Quad>.stride)
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(
            1, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: 0 + 0))
        glVertexAttribDivisor(1, 1)

        let off_dst_p1 = MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(2)
        glVertexAttribPointer(
            2, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_dst_p1))
        glVertexAttribDivisor(2, 1)

        let off_tex_tl = off_dst_p1 + MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(3)
        glVertexAttribPointer(
            3, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_tl))
        glVertexAttribDivisor(3, 1)

        let off_tex_br = off_tex_tl + MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(4)
        glVertexAttribPointer(
            4, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_tex_br))
        glVertexAttribDivisor(4, 1)

        let off_color = off_tex_br + MemoryLayout<(GLfloat, GLfloat)>.stride
        glEnableVertexAttribArray(5)
        glVertexAttribPointer(
            5, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, UnsafeRawPointer(bitPattern: off_color))
        glVertexAttribDivisor(5, 1)

        glGenTextures(1, &whiteTex)
        glBindTexture(GLenum(GL_TEXTURE_2D), whiteTex)
        let px: [UInt8] = [255, 255, 255, 255]
        px.withUnsafeBytes { p in
            glTexImage2D(
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

    static var atlasW = 0
    static var atlasH = 0
    private static var font5x7 = Array(repeating: Glyph(), count: 128)

    static func initFont() {
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
        set("0", ["01110", "10001", "10011", "10101", "11001", "10001", "01110"])
        set(
            "1",
            [
                "00100",
                "01100",
                "00100",
                "00100",
                "00100",
                "00100",
                "01110",
            ])

        set(
            "2",
            [
                "01110",
                "10001",
                "00001",
                "00110",
                "01000",
                "10000",
                "11111",
            ])

        set(
            "3",
            [
                "11110",
                "00001",
                "00001",
                "01110",
                "00001",
                "00001",
                "11110",
            ])

        set(
            "4",
            [
                "00010",
                "00110",
                "01010",
                "10010",
                "11111",
                "00010",
                "00010",
            ])

        set(
            "5",
            [
                "11111",
                "10000",
                "11110",
                "00001",
                "00001",
                "10001",
                "01110",
            ])

        set(
            "6",
            [
                "01110",
                "10000",
                "11110",
                "10001",
                "10001",
                "10001",
                "01110",
            ])

        set(
            "7",
            [
                "11111",
                "00001",
                "00010",
                "00100",
                "01000",
                "01000",
                "01000",
            ])

        set(
            "8",
            [
                "01110",
                "10001",
                "10001",
                "01110",
                "10001",
                "10001",
                "01110",
            ])

        set(
            "9",
            [
                "01110",
                "10001",
                "10001",
                "01111",
                "00001",
                "00001",
                "01110",
            ])
    }

    static func createFontAtlas() {
        atlasW = charCount * (glyphW + glyphSpacing)
        atlasH = glyphH
        let pixelsCount = atlasW * atlasH * 4
        let img = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelsCount)
        img.initialize(repeating: 0, count: pixelsCount)
        defer { img.deallocate() }

        for c in Int(firstChar)...Int(lastChar) {
            let g = font5x7[c]
            let xoff = (c - Int(firstChar)) * (glyphW + glyphSpacing)
            if !g.rows[0].isEmpty {
                for y in 0..<glyphH {
                    let row = Array(g.rows[y])
                    for x in 0..<glyphW {
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

    static let EGL_NO_CONTEXT: EGLContext? = EGLContext(bitPattern: 0)
    static let EGL_NO_DISPLAY: EGLDisplay? = EGLDisplay(bitPattern: 0)
    static let EGL_NO_SURFACE: EGLSurface? = EGLSurface(bitPattern: 0)

    static var eglDisplay: EGLDisplay!
    static var eglContext: EGLContext!
    static var eglSurface: EGLSurface!
    static var eglWindow: OpaquePointer!
    static var winW: Int32 = 800
    static var winH: Int32 = 600

    nonisolated(unsafe) static var display: OpaquePointer!
    static var compositor: OpaquePointer!
    static var toplevel: OpaquePointer!
    static var wmBase: OpaquePointer!
    static var surface: OpaquePointer!
    static var xdgSurface: OpaquePointer!
    static var registry: OpaquePointer!
    static var registryListener = wl_registry_listener(global: onGlobal, global_remove: onGlobalRemove)
    static var seat: OpaquePointer!
    static var keyboard: OpaquePointer!

    static var _wl_seat_interface: wl_interface = wl_seat_interface
    static var _wl_compositor_interface: wl_interface = wl_compositor_interface
    static var _xdg_wm_base_interface: wl_interface = xdg_wm_base_interface

    static var wmBaseListener = xdg_wm_base_listener(
        ping: { _, base, serial in
            xdg_wm_base_pong(base, serial)
        }
    )

    static var xdgSurfaceListener = xdg_surface_listener(
        configure: { _, surface, serial in
            xdg_surface_ack_configure(surface, serial)
        }
    )

    static var frameListener = wl_callback_listener(
        done: { _, callback, _time in
            wl_callback_destroy(callback)
            WaylandEvents.send(.frame)
        }
    )

    static var seatListener = wl_seat_listener(
        capabilities: seat_capabilities_cb,
        name: { _, _, _ in }  // we don’t use "name" here
    )

    static var keyboard_listener = wl_keyboard_listener(
        keymap: keyboard_keymap_cb,
        enter: keyboard_enter_cb,
        leave: keyboard_leave_cb,
        key: keyboard_key_cb,
        modifiers: keyboard_modifiers_cb,
        repeat_info: keyboard_repeat_info_cb
    )

    static var start = ContinuousClock.now
    static var end = ContinuousClock.now

    static func scheduleNextFrame() {
        let cb = wl_surface_frame(surface)
        wl_callback_add_listener(cb, &frameListener, nil)
        wl_surface_commit(surface)
    }

    static let onGlobal:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32, UnsafePointer<CChar>?, UInt32
        ) -> Void = { _, registry, id, interface, version in
            guard let cstr = interface else { return }
            let iface = String(cString: cstr)
            switch iface {
            case "wl_compositor":
                compositor = OpaquePointer(
                    wl_registry_bind(registry, id, &_wl_compositor_interface, min(version, 4))
                )
            case "xdg_wm_base":
                wmBase = OpaquePointer(
                    wl_registry_bind(registry, id, &_xdg_wm_base_interface, min(version, 2))
                )
                xdg_wm_base_add_listener(wmBase, &wmBaseListener, nil)
            case "wl_seat":
                seat = OpaquePointer(
                    wl_registry_bind(registry, id, &_wl_seat_interface, min(version, 5))
                )
                wl_seat_add_listener(seat, &seatListener, nil)
            default:
                ()
            }
        }

    static let onGlobalRemove:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32
        ) -> Void = { _, _, name in
        }

    static let keyboard_keymap_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32, Int32, UInt32
        ) -> Void = { _, _, _, shared_fd, _ in
            close(shared_fd)
        }

    static let keyboard_enter_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32, OpaquePointer?, UnsafeMutablePointer<wl_array>?
        ) -> Void = { _, _, _, _, _ in
        }

    static let keyboard_leave_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32, OpaquePointer?
        ) -> Void = { _, _, _, _ in
        }

    static let keyboard_key_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32, UInt32, UInt32, UInt32
        ) -> Void = { _, _, _, _, key, state in
            WaylandEvents.send(.key(code: key, state: state))
        }

    static let keyboard_modifiers_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32, UInt32, UInt32, UInt32, UInt32
        ) -> Void = { _, _, _, _, _, _, _ in
        }

    static let keyboard_repeat_info_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, Int32, Int32
        ) -> Void = { _, _, _, _ in
        }

    static let seat_capabilities_cb:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?, UInt32
        ) -> Void = { _, s, caps in
            let WL_SEAT_CAPABILITY_KEYBOARD: UInt32 = 1  // bit 0
            if (caps & WL_SEAT_CAPABILITY_KEYBOARD) != 0 && keyboard == nil {
                keyboard = wl_seat_get_keyboard(s)
                wl_keyboard_add_listener(keyboard, &keyboard_listener, nil)
            }
        }

    static var xdgToplevelListener = xdg_toplevel_listener(
        configure: xdg_toplevel_configure_cb,
        close: { _, _ in },
        configure_bounds: { _, _, _, _ in },
        wm_capabilities: { _, _, _ in }
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
                if eglWindow != nil {
                    wl_egl_window_resize(eglWindow, winW, winH, 0, 0)
                    glBindVertexArray(vao)
                    glBindVertexArray(0)
                }
            }
        }
}

enum WaylandEvent {
    case key(code: UInt32, state: UInt32)
    case frame
}

@MainActor
enum WaylandEvents {
    private static var continuation: AsyncStream<WaylandEvent>.Continuation?

    static func events() -> AsyncStream<WaylandEvent> {
        AsyncStream { cont in continuation = cont }
    }

    static func send(_ ev: WaylandEvent) {
        continuation?.yield(ev)
    }
}
