import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CWaylandProtocols
import Foundation
import ShapeTree

@MainActor
public func calculateLayout(_ block: some Block) -> Layout {
  calculateLayout(block, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)
}

@MainActor
protocol Renderer {
  static func drawText(_ text: RenderableText)
  static func drawQuad(_ quad: RenderableQuad)
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

@MainActor
struct Glyph {
  var rows: [String] = Array(repeating: "", count: Int(Wayland.glyphH))
}

@MainActor
public struct WaylandFontMetrics: FontMetrics {
  public let glyphWidth: UInt = Wayland.glyphW
  public let glyphHeight: UInt = Wayland.glyphH
  public let glyphSpacing: UInt = Wayland.glyphSpacing
  public let scale: UInt = 1
}

/// There is a lot of global state here to setup and conform to Wayland's patterns.
/// There might be better ways to abstract this and clean it up a bit. But it's
/// working for now.
@MainActor
public enum Wayland: Renderer {

  // MARK: - Constants & Metrics

  public static let fontSettings: any FontMetrics = WaylandFontMetrics()
  public internal(set) static var state: State = .running

  public static let glyphW: UInt = 5
  public static let glyphH: UInt = 7
  public static let glyphSpacing: UInt = 1

  static let firstChar: UInt8 = 32
  static let lastChar: UInt8 = 126
  static let charCount = UInt(lastChar - firstChar + 1)
  static var atlasW = Int(charCount * (glyphW + glyphSpacing))
  static var atlasH = Int(glyphH)

  // MARK: - Window Dimensions

  static var windowWidth: UInt = 800
  #if Toolbar
  public static let toolbar_height: UInt = 20
  static var windowHeight: UInt = toolbar_height
  #else
  static var windowHeight: UInt = 600
  #endif

  // MARK: - EGL State

  static var eglDisplay: EGLDisplay?
  static var eglContext: EGLContext?
  static var eglSurface: EGLSurface?
  static var eglWindow: OpaquePointer?

  static let EGL_NO_CONTEXT: EGLContext? = unsafe EGLContext(bitPattern: 0)
  static let EGL_NO_DISPLAY: EGLDisplay? = unsafe EGLDisplay(bitPattern: 0)
  static let EGL_NO_SURFACE: EGLSurface? = unsafe EGLSurface(bitPattern: 0)

  // MARK: - OpenGL Handles

  static var program: GLuint = 0
  static var vao: GLuint = 0
  static var fontTex: GLuint = 0
  static var whiteTex: GLuint = 0
  static var quadVBO: GLuint = 0
  static var instanceVBO: GLuint = 0
  static var uRes: GLint = 0
  static var uTex: GLint = 0

  // MARK: - Wayland Protocol Objects

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

  #else
  static var xdgSurface: OpaquePointer!
  #endif

  // MARK: - Timing & FPS

  static var start = ContinuousClock.now
  static var end = ContinuousClock.now
  public internal(set) static var elapsed: Duration = end - start

  public internal(set) static var refresh_rate: Duration = .milliseconds(16)
  static var lastFrameTime: ContinuousClock.Instant = ContinuousClock.now
  static var frameCount: UInt = 0
  static var fps: Double = 0.0
  static var fpsUpdateTime: ContinuousClock.Instant = ContinuousClock.now

  // MARK: - Public API

  public static func exit() {
    state = .exit
  }

  public static var currentFPS: Double {
    fps
  }

  // MARK: - Shader Loading

  static func loadText(resource name: String) -> String {
    switch name {
    case "vertex.glsl":
      return vertexShader
    case "fragment.glsl":
      return fragmentShader
    default:
      fatalError("Unknown shader resource: \(name)")
    }
  }

  // MARK: - Frame Lifecycle

  public static func preDraw() {
    start = ContinuousClock.now

    glViewport(0, 0, GLsizei(windowWidth), GLsizei(windowHeight))
    glClearColor(0, 0, 0, 1)
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

    glUseProgram(program)
    glUniform2f(uRes, Float(windowWidth), Float(windowHeight))
    glUniform1i(uTex, 0)

    glBindVertexArray(vao)
  }

  public static func postDraw() {
    _ = unsafe eglSwapBuffers(eglDisplay, eglSurface)
    unsafe wl_surface_damage_buffer(surface, 0, 0, INT32_MAX, INT32_MAX)
    unsafe wl_surface_commit(surface)
    end = ContinuousClock.now
    elapsed = end - start
  }

  // MARK: - Wayland Listeners

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

  // MARK: - Setup

  public static func setup(_ refresh_rate: Duration = refresh_rate) {
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

      send(.frame(height: UInt(windowHeight), width: UInt(windowWidth)))
    }
  }

  // MARK: - Protocol Callbacks

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
        windowWidth = UInt(width)
        windowHeight = UInt(height)
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
      windowWidth = UInt(width)
      windowHeight = UInt(height)
      unsafe zwlr_layer_surface_v1_ack_configure(_surface, serial)

      if let eglWin = unsafe eglWindow {
        unsafe wl_egl_window_resize(eglWin, Int32(windowWidth), Int32(windowHeight), 0, 0)
      }

      glViewport(0, 0, GLsizei(windowWidth), GLsizei(windowHeight))
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

  // MARK: - Event Loop

  /// I am using this event loop so that I can have async suspension points in "user space"
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
    calledOnce = false
    Task {
      // Render loop
      while Wayland.state.isRunning {
        try? await Task.sleep(for: refresh_rate)

        // Calculate FPS
        let now = ContinuousClock.now
        let frameDelta = now - lastFrameTime
        lastFrameTime = now

        frameCount += 1
        let fpsDelta = now - fpsUpdateTime
        if fpsDelta >= .seconds(1) {
          fps = Double(frameCount) / Double(fpsDelta.components.seconds)
          frameCount = 0
          fpsUpdateTime = now
        }

        send(.frame(height: UInt(windowHeight), width: UInt(windowWidth)))
      }
      continuation?.finish()
    }
    return AsyncStream { cont in continuation = cont }
  }

  private static func send(_ ev: WaylandEvent) {
    continuation?.yield(ev)
  }
}
