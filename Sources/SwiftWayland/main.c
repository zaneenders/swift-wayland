
#include "xdg-shell-client-protocol.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <wayland-egl.h>

struct client_state {
  struct wl_display *wl_display;
  struct wl_compositor *wl_compositor;
  struct wl_surface *wl_surface;
  struct wl_shm *wl_shm;
  struct xdg_wm_base *xdg_wm_base;
  struct xdg_surface *xdg_surface;
  struct xdg_toplevel *xdg_toplevel;
  int width, height;
  bool closed;
  EGLDisplay egl_display;
  EGLContext egl_context;
  EGLSurface egl_surface;
  struct wl_egl_window *egl_window;
  EGLConfig config;
};

GLuint program = 0;
GLuint vbo = 0;
GLint a_position = -1;
GLint u_time = -1;
struct timespec start_ts;

static GLuint compile_shader(GLenum type, const char *src) {
  GLuint s = glCreateShader(type);
  glShaderSource(s, 1, &src, NULL);
  glCompileShader(s);
  GLint ok = 0;
  glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[1024];
    GLsizei n = 0;
    glGetShaderInfoLog(s, sizeof log, &n, log);
    fprintf(stderr, "Shader compile error: %.*s\n", n, log);
    glDeleteShader(s);
    return 0;
  }
  return s;
}

static GLuint link_program(GLuint vs, GLuint fs) {
  GLuint p = glCreateProgram();
  glAttachShader(p, vs);
  glAttachShader(p, fs);
  glLinkProgram(p);
  GLint ok = 0;
  glGetProgramiv(p, GL_LINK_STATUS, &ok);
  if (!ok) {
    char log[1024];
    GLsizei n = 0;
    glGetProgramInfoLog(p, sizeof log, &n, log);
    fprintf(stderr, "Program link error: %.*s\n", n, log);
    glDeleteProgram(p);
    return 0;
  }
  glDetachShader(p, vs);
  glDetachShader(p, fs);
  glDeleteShader(vs);
  glDeleteShader(fs);
  return p;
}

static bool init_gles_resources(struct client_state *state) {
  const char *vs_src = "attribute vec3 a_position;\n"
                       "void main(){\n"
                       "  gl_Position = vec4(a_position, 1.0);\n"
                       "}\n";

  const char *fs_src = "precision mediump float;\n"
                       "uniform float u_time;\n"
                       "void main(){\n"
                       "  float r = 0.3 + 0.3 * abs(sin(u_time));\n"
                       "  float g = 0.5 + 0.5 * abs(sin(u_time*0.7));\n"
                       "  float b = 0.8;\n"
                       "  gl_FragColor = vec4(r,g,b,1.0);\n"
                       "}\n";

  GLuint vs = compile_shader(GL_VERTEX_SHADER, vs_src);
  if (!vs)
    return false;
  GLuint fs = compile_shader(GL_FRAGMENT_SHADER, fs_src);
  if (!fs)
    return false;

  program = link_program(vs, fs);
  if (!program)
    return false;

  const GLfloat vertices[] = {
      0.0f, 0.6f, 0.0f, -0.6f, -0.6f, 0.0f, 0.6f, -0.6f, 0.0f,
  };

  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  a_position = glGetAttribLocation(program, "a_position");
  u_time = glGetUniformLocation(program, "u_time");

  clock_gettime(CLOCK_MONOTONIC, &start_ts);
  return true;
}

static EGLDisplay get_wayland_display(struct wl_display *wl) {
  PFNEGLGETPLATFORMDISPLAYPROC eglGetPlatformDisplayKHR =
      (PFNEGLGETPLATFORMDISPLAYPROC)eglGetProcAddress("eglGetPlatformDisplay");
  if (eglGetPlatformDisplayKHR) {
    EGLDisplay dpy =
        eglGetPlatformDisplayKHR(EGL_PLATFORM_WAYLAND_KHR, wl, NULL);
    if (dpy != EGL_NO_DISPLAY)
      return dpy;
  }
  return eglGetDisplay((EGLNativeDisplayType)wl);
}

static bool init_gl(struct client_state *state) {
  state->egl_display = get_wayland_display(state->wl_display);
  if (state->egl_display == EGL_NO_DISPLAY) {
    fprintf(stderr, "eglGetPlatformDisplay/eglGetDisplay failed\n");
    return false;
  }
  if (!eglInitialize(state->egl_display, NULL, NULL)) {
    fprintf(stderr, "eglInitialize failed (0x%x)\n", eglGetError());
    return false;
  }

  EGLint config_attribs[] = {EGL_SURFACE_TYPE,
                             EGL_WINDOW_BIT,
                             EGL_RED_SIZE,
                             8,
                             EGL_GREEN_SIZE,
                             8,
                             EGL_BLUE_SIZE,
                             8,
                             EGL_ALPHA_SIZE,
                             8,
                             EGL_RENDERABLE_TYPE,
                             EGL_OPENGL_ES2_BIT,
                             EGL_NONE};

  EGLint num_config = 0;
  if (!eglChooseConfig(state->egl_display, config_attribs, &state->config, 1,
                       &num_config) ||
      num_config < 1) {
    fprintf(stderr, "eglChooseConfig failed (0x%x)\n", eglGetError());
    return false;
  }

  if (!eglBindAPI(EGL_OPENGL_ES_API)) {
    fprintf(stderr, "eglBindAPI failed (0x%x)\n", eglGetError());
    return false;
  }

  const EGLint ctx_attribs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  state->egl_context = eglCreateContext(state->egl_display, state->config,
                                        EGL_NO_CONTEXT, ctx_attribs);
  if (state->egl_context == EGL_NO_CONTEXT) {
    fprintf(stderr, "eglCreateContext failed (0x%x)\n", eglGetError());
    return false;
  }
  return true;
}

static void xdg_wm_base_ping(void *data, struct xdg_wm_base *xdg_wm_base,
                             uint32_t serial) {
  xdg_wm_base_pong(xdg_wm_base, serial);
}

static const struct xdg_wm_base_listener xdg_wm_base_listener = {
    .ping = xdg_wm_base_ping,
};

static void xdg_toplevel_configure(void *data,
                                   struct xdg_toplevel *xdg_toplevel,
                                   int32_t width, int32_t height,
                                   struct wl_array *states) {
  struct client_state *state = data;
  if (width == 0 || height == 0) {
    return;
  }
  state->width = width;
  state->height = height;

  if (state->egl_window) {
    wl_egl_window_resize(state->egl_window, width, height, 0, 0);
  }
}

static void _xdg_toplevel_configure(void *data,
                                    struct xdg_toplevel *xdg_toplevel,
                                    int32_t width, int32_t height,
                                    struct wl_array *states) {
  struct client_state *state = data;
  if (width == 0 || height == 0) {
    return;
  }
  state->width = width;
  state->height = height;
}

static void xdg_toplevel_close(void *data, struct xdg_toplevel *toplevel) {
  struct client_state *state = data;
  printf("goodbye\n");
  state->closed = true;
}

static void xdg_toplevel_configure_bounds(void *data,
                                          struct xdg_toplevel *xdg_toplevel,
                                          int32_t width, int32_t height) {
  // This event notifies the client of the maximum and minimum window size.
}

static void xdg_toplevel_wm_capabilities(void *data,
                                         struct xdg_toplevel *xdg_toplevel,
                                         struct wl_array *capabilities) {
  // This event notifies the client of supported window management features.
  // Providing a handler here prevents the "NULL listener" warning.
}

static const struct xdg_toplevel_listener xdg_toplevel_listener = {
    .configure = xdg_toplevel_configure,
    .close = xdg_toplevel_close,
    .configure_bounds = xdg_toplevel_configure_bounds,
    .wm_capabilities = xdg_toplevel_wm_capabilities,
};

void draw_frame(struct client_state *state);

static void frame_done(void *data, struct wl_callback *callback,
                       uint32_t time) {
  struct client_state *state = data;
  wl_callback_destroy(callback);
  draw_frame(state);
}

static const struct wl_callback_listener frame_listener = {
    .done = frame_done,
};

static void xdg_surface_configure(void *data, struct xdg_surface *xdg_surface,
                                  uint32_t serial) {
  struct client_state *state = data;
  xdg_surface_ack_configure(xdg_surface, serial);

  struct wl_callback *callback = wl_surface_frame(state->wl_surface);
  wl_callback_add_listener(callback, &frame_listener, state);

  draw_frame(state);
}

void draw_frame(struct client_state *state) {
  eglMakeCurrent(state->egl_display, state->egl_surface, state->egl_surface,
                 state->egl_context);

  glViewport(0, 0, state->width, state->height);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgram(program);

  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  float t =
      (ts.tv_sec - start_ts.tv_sec) + (ts.tv_nsec - start_ts.tv_nsec) / 1e9f;
  if (u_time >= 0)
    glUniform1f(u_time, t);

  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  if (a_position >= 0) {
    glEnableVertexAttribArray(a_position);
    glVertexAttribPointer(a_position, 3, GL_FLOAT, GL_FALSE,
                          3 * sizeof(GLfloat), (void *)0);
  }

  glDrawArrays(GL_TRIANGLES, 0, 3);

  if (a_position >= 0)
    glDisableVertexAttribArray(a_position);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glUseProgram(0);

  eglSwapBuffers(state->egl_display, state->egl_surface);

  struct wl_callback *callback = wl_surface_frame(state->wl_surface);
  wl_callback_add_listener(callback, &frame_listener, state);
  wl_surface_commit(state->wl_surface);
  wl_display_flush(state->wl_display);
}

static const struct xdg_surface_listener xdg_surface_listener = {
    .configure = xdg_surface_configure,
};

static void registry_handle_global(void *data, struct wl_registry *registry,
                                   uint32_t name, const char *interface,
                                   uint32_t version) {
  struct client_state *state = data;
  if (strcmp(interface, "wl_compositor") == 0) {
    state->wl_compositor =
        wl_registry_bind(registry, name, &wl_compositor_interface, version);
  } else if (strcmp(interface, "wl_shm") == 0) {
    state->wl_shm =
        wl_registry_bind(registry, name, &wl_shm_interface, version);
  } else if (strcmp(interface, "xdg_wm_base") == 0) {
    state->xdg_wm_base =
        wl_registry_bind(registry, name, &xdg_wm_base_interface, version);
  }
}

static void registry_handle_global_remove(void *data,
                                          struct wl_registry *registry,
                                          uint32_t name) {
  // Skipped for now.
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_handle_global,
    .global_remove = registry_handle_global_remove,
};

int main(int argc, char *argv[]) {
  struct client_state state = {0};
  state.width = 800;
  state.height = 600;

  state.wl_display = wl_display_connect(NULL);
  if (!state.wl_display) {
    fprintf(stderr, "Failed to connect to Wayland display.\n");
    return 1;
  }

  struct wl_registry *registry = wl_display_get_registry(state.wl_display);
  wl_registry_add_listener(registry, &registry_listener, &state);
  wl_display_roundtrip(state.wl_display);

  if (!state.wl_compositor || !state.wl_shm || !state.xdg_wm_base) {
    fprintf(stderr, "Failed to find essential Wayland interfaces.\n");
    return 1;
  }

  xdg_wm_base_add_listener(state.xdg_wm_base, &xdg_wm_base_listener, &state);

  state.wl_surface = wl_compositor_create_surface(state.wl_compositor);
  state.xdg_surface =
      xdg_wm_base_get_xdg_surface(state.xdg_wm_base, state.wl_surface);
  xdg_surface_add_listener(state.xdg_surface, &xdg_surface_listener, &state);

  state.xdg_toplevel = xdg_surface_get_toplevel(state.xdg_surface);
  xdg_toplevel_add_listener(state.xdg_toplevel, &xdg_toplevel_listener, &state);
  xdg_toplevel_set_title(state.xdg_toplevel, "Hello Wayland");

  init_gl(&state);

  state.egl_window =
      wl_egl_window_create(state.wl_surface, state.width, state.height);
  if (!state.egl_window) {
    fprintf(stderr, "wl_egl_window_create failed\n");
    return 1;
  }

  state.egl_surface =
      eglCreateWindowSurface(state.egl_display, state.config,
                             (EGLNativeWindowType)state.egl_window, NULL);
  if (state.egl_surface == EGL_NO_SURFACE) {
    fprintf(stderr, "eglCreateWindowSurface failed (0x%x)\n", eglGetError());
    return 1;
  }

  if (!eglMakeCurrent(state.egl_display, state.egl_surface, state.egl_surface,
                      state.egl_context)) {
    fprintf(stderr, "eglMakeCurrent failed (0x%x)\n", eglGetError());
    return 1;
  }

  if (!init_gles_resources(&state)) {
    fprintf(stderr, "Failed to init GL resources\n");
    return 1;
  }

  wl_surface_commit(state.wl_surface);
  wl_display_roundtrip(state.wl_display);

  while (!state.closed && wl_display_dispatch(state.wl_display) != -1) {
    printf("Loop\n");
  }

  xdg_toplevel_destroy(state.xdg_toplevel);
  xdg_surface_destroy(state.xdg_surface);
  wl_egl_window_destroy(state.egl_window);
  eglDestroySurface(state.egl_display, state.egl_surface);
  eglDestroyContext(state.egl_display, state.egl_context);
  eglTerminate(state.egl_display);
  wl_surface_destroy(state.wl_surface);
  //  wl_registry_destroy(state.registry);
  wl_display_disconnect(state.wl_display);
  return 0;
}
