import CEGL
import CWaylandClient
import CWaylandEGL

extension Wayland {

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

    unsafe eglWindow = wl_egl_window_create(surface, Int32(windowWidth), Int32(windowHeight))
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
}
