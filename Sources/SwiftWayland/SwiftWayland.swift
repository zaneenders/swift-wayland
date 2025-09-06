import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CXDGShell
import Foundation

actor State {
    var count = 0

    init() {
        Task {
            await start()
        }
    }

    func start() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self.count += 1
            }
        }
    }

    func get() -> Int {
        return count
    }
}

@main
@MainActor
struct SwiftWayland {
    static func main() async {
        let state = State()
        Wayland.setup()
        event_loop: for await ev in WaylandEvents.events() {
            let state = await state.get()
            switch ev {
            case .frame:
                Wayland.drawFrame()
                print("count: \(state)")
            case .key(let code, let state):
                if code == 1 {
                    return
                }
                print(code, state)
            }
        }
    }
}

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

            DispatchQueue.global().async {
                while wl_display_dispatch(display) != -1 {}
            }
            WaylandEvents.send(.frame)
        }
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

    static func drawFrame() {
        glViewport(0, 0, GLsizei(winW), GLsizei(winH))
        glClearColor(0.1, 0.2, 0.3, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        eglSwapBuffers(eglDisplay, eglSurface)
        scheduleNextFrame()
        end = ContinuousClock.now
        print(#function, end - start)
        start = ContinuousClock.now
    }

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
