#include "xdg-shell-client-protocol.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <linux/input-event-codes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <wayland-egl.h>

static struct wl_display *display;
static struct wl_registry *registry;
static struct wl_compositor *compositor;
static struct xdg_wm_base *wm_base;
static struct wl_seat *seat;
static struct wl_keyboard *keyboard;

static struct wl_surface *surface;
static struct xdg_surface *xdg_surface;
static struct xdg_toplevel *xdg_toplevel;
static struct wl_callback *frame_callback;

static bool running = true;
static bool configured = false;

static struct wl_egl_window *egl_window;
static EGLDisplay egl_display;
static EGLContext egl_context;
static EGLSurface egl_surface;

static int win_w = 640;
static int win_h = 480;

static double start_time = 0.0;
static float anim_value = 0.0f;

static GLuint program = 0;
static GLuint vbo = 0;

static double get_time_ms() {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1000.0 + ts.tv_nsec / 1.0e6;
}

static GLuint compile_shader(GLenum type, const char *src) {
  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &src, NULL);
  glCompileShader(shader);
  GLint ok;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[512];
    glGetShaderInfoLog(shader, sizeof(log), NULL, log);
    fprintf(stderr, "Shader compile error: %s\n", log);
    exit(1);
  }
  return shader;
}

static void init_shaders() {
  const char *vs_src =
      "attribute vec2 pos; void main() { gl_Position = vec4(pos, 0.0, 1.0); }";
  const char *fs_src =
      "precision mediump float; uniform float u_anim; void main() { "
      "gl_FragColor = vec4(u_anim, 0.3, 1.0-u_anim, 1.0); }";

  GLuint vs = compile_shader(GL_VERTEX_SHADER, vs_src);
  GLuint fs = compile_shader(GL_FRAGMENT_SHADER, fs_src);

  program = glCreateProgram();
  glAttachShader(program, vs);
  glAttachShader(program, fs);
  glLinkProgram(program);
  GLint ok;
  glGetProgramiv(program, GL_LINK_STATUS, &ok);
  if (!ok) {
    char log[512];
    glGetProgramInfoLog(program, sizeof(log), NULL, log);
    fprintf(stderr, "Program link error: %s\n", log);
    exit(1);
  }
  glDeleteShader(vs);
  glDeleteShader(fs);

  GLfloat verts[] = {0.0f, 0.5f, -0.5f, -0.5f, 0.5f, -0.5f};

  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
}

static void xdg_wm_base_ping(void *data, struct xdg_wm_base *xdg_wm_base,
                             uint32_t serial) {
  xdg_wm_base_pong(xdg_wm_base, serial);
}

static const struct xdg_wm_base_listener wm_base_listener = {
    .ping = xdg_wm_base_ping,
};

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface,
                            uint32_t version) {
  if (strcmp(interface, "wl_compositor") == 0) {
    compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 4);
  } else if (strcmp(interface, "xdg_wm_base") == 0) {
    wm_base = wl_registry_bind(registry, name, &xdg_wm_base_interface, 2);
    xdg_wm_base_add_listener(wm_base, &wm_base_listener, NULL);
  } else if (strcmp(interface, "wl_seat") == 0) {
    seat = wl_registry_bind(registry, name, &wl_seat_interface, 5);
  }
}

static void registry_global_remove(void *data, struct wl_registry *registry,
                                   uint32_t name) {}
static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static void draw_frame(double ms) {
  anim_value = (float)fmod(ms / 3000.0, 1.0);

  glViewport(0, 0, win_w, win_h);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgram(program);
  GLint loc = glGetUniformLocation(program, "u_anim");
  glUniform1f(loc, anim_value);

  GLint apos = glGetAttribLocation(program, "pos");
  glEnableVertexAttribArray(apos);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glVertexAttribPointer(apos, 2, GL_FLOAT, GL_FALSE, 0, 0);

  glDrawArrays(GL_TRIANGLES, 0, 3);

  glDisableVertexAttribArray(apos);

  eglSwapBuffers(egl_display, egl_surface);
}

static void frame_done(void *data, struct wl_callback *callback, uint32_t time);
static const struct wl_callback_listener frame_listener = {frame_done};

static void schedule_next_frame_and_commit(void) {
  frame_callback = wl_surface_frame(surface);
  wl_callback_add_listener(frame_callback, &frame_listener, NULL);

  wl_surface_damage_buffer(surface, 0, 0, win_w, win_h);
  wl_surface_commit(surface);
}

static void frame_done(void *data, struct wl_callback *callback,
                       uint32_t time) {
  if (callback)
    wl_callback_destroy(callback);
  if (!configured)
    return;

  double ms = get_time_ms() - start_time;
  draw_frame(ms);
  schedule_next_frame_and_commit();
}

static void xdg_surface_configure(void *data, struct xdg_surface *xs,
                                  uint32_t serial) {
  xdg_surface_ack_configure(xs, serial);
  if (!configured) {
    configured = true;
    start_time = get_time_ms();
    double ms = 0.0;
    draw_frame(ms);
    schedule_next_frame_and_commit();
  }
}

static const struct xdg_surface_listener xdg_surface_listener = {
    .configure = xdg_surface_configure,
};

static void xdg_toplevel_configure(void *data, struct xdg_toplevel *tl,
                                   int32_t width, int32_t height,
                                   struct wl_array *states) {
  if (width > 0 && height > 0) {
    win_w = width;
    win_h = height;
    if (egl_window)
      wl_egl_window_resize(egl_window, win_w, win_h, 0, 0);
  }
}

static void xdg_toplevel_close(void *data, struct xdg_toplevel *tl) {
  running = false;
}

static const struct xdg_toplevel_listener xdg_toplevel_listener = {
    .configure = xdg_toplevel_configure,
    .close = xdg_toplevel_close,
};

static void keyboard_keymap(void *data, struct wl_keyboard *kb, uint32_t format,
                            int shared_fd, uint32_t size) {
  close(shared_fd);
}

static void keyboard_enter(void *data, struct wl_keyboard *kb, uint32_t serial,
                           struct wl_surface *surface, struct wl_array *keys) {}

static void keyboard_leave(void *data, struct wl_keyboard *kb, uint32_t serial,
                           struct wl_surface *surface) {}

static void keyboard_key(void *data, struct wl_keyboard *kb, uint32_t serial,
                         uint32_t time, uint32_t key, uint32_t state) {
  if (state == WL_KEYBOARD_KEY_STATE_PRESSED) {
    if (key == KEY_ESC) {
      fprintf(stderr, "ESC pressed, exiting.\n");
      running = false;
    } else {
      fprintf(stderr, "Key pressed: %u\n", key);
    }
  }
}

static void keyboard_modifiers(void *data, struct wl_keyboard *kb,
                               uint32_t serial, uint32_t mods_depressed,
                               uint32_t mods_latched, uint32_t mods_locked,
                               uint32_t group) {}

static void keyboard_repeat_info(void *data, struct wl_keyboard *kb,
                                 int32_t rate, int32_t delay) {}

static const struct wl_keyboard_listener keyboard_listener = {
    .keymap = keyboard_keymap,
    .enter = keyboard_enter,
    .leave = keyboard_leave,
    .key = keyboard_key,
    .modifiers = keyboard_modifiers,
    .repeat_info = keyboard_repeat_info,
};

static void seat_capabilities(void *data, struct wl_seat *s,
                              enum wl_seat_capability caps) {
  if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !keyboard) {
    keyboard = wl_seat_get_keyboard(s);
    wl_keyboard_add_listener(keyboard, &keyboard_listener, NULL);
  } else if (!(caps & WL_SEAT_CAPABILITY_KEYBOARD) && keyboard) {
    wl_keyboard_destroy(keyboard);
    keyboard = NULL;
  }
}

static void seat_name(void *data, struct wl_seat *s, const char *name) {}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

static void init_egl(struct wl_surface *wl_surface) {
  egl_display = eglGetDisplay((EGLNativeDisplayType)display);
  if (!egl_display) {
    fprintf(stderr, "eglGetDisplay failed\n");
    exit(1);
  }
  if (!eglInitialize(egl_display, NULL, NULL)) {
    fprintf(stderr, "eglInitialize failed\n");
    exit(1);
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
  EGLConfig config;
  EGLint n = 0;
  if (!eglChooseConfig(egl_display, config_attribs, &config, 1, &n) || n == 0) {
    fprintf(stderr, "eglChooseConfig failed\n");
    exit(1);
  }

  EGLint ctx_attribs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  egl_context =
      eglCreateContext(egl_display, config, EGL_NO_CONTEXT, ctx_attribs);
  if (egl_context == EGL_NO_CONTEXT) {
    fprintf(stderr, "eglCreateContext failed\n");
    exit(1);
  }

  egl_window = wl_egl_window_create(wl_surface, win_w, win_h);
  if (!egl_window) {
    fprintf(stderr, "wl_egl_window_create failed\n");
    exit(1);
  }

  egl_surface = eglCreateWindowSurface(egl_display, config,
                                       (EGLNativeWindowType)egl_window, NULL);
  if (egl_surface == EGL_NO_SURFACE) {
    fprintf(stderr, "eglCreateWindowSurface failed\n");
    exit(1);
  }

  if (!eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context)) {
    fprintf(stderr, "eglMakeCurrent failed\n");
    exit(1);
  }
  eglSwapInterval(egl_display, 1);
}

int main() {
  display = wl_display_connect(NULL);
  if (!display) {
    fprintf(stderr, "Failed to connect to Wayland display.\n");
    return -1;
  }

  registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &registry_listener, NULL);
  wl_display_roundtrip(display);

  if (seat)
    wl_seat_add_listener(seat, &seat_listener, NULL);

  if (!compositor || !wm_base) {
    fprintf(stderr, "Compositor or wm_base not available.\n");
    return -1;
  }

  surface = wl_compositor_create_surface(compositor);
  xdg_surface = xdg_wm_base_get_xdg_surface(wm_base, surface);
  xdg_surface_add_listener(xdg_surface, &xdg_surface_listener, NULL);

  xdg_toplevel = xdg_surface_get_toplevel(xdg_surface);
  xdg_toplevel_add_listener(xdg_toplevel, &xdg_toplevel_listener, NULL);
  xdg_toplevel_set_title(xdg_toplevel, "Swift Wayland");

  wl_surface_commit(surface);

  init_egl(surface);
  init_shaders();

  while (running && wl_display_dispatch(display) != -1) {
    // noop
  }

  return 0;
}
