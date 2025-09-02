#include "xdg-shell-client-protocol.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <linux/input-event-codes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include <wayland-egl.h>

static GLuint program = 0;
static GLuint vertextBufferObject = 0;
static GLuint vertexArrayObject = 0;
static GLuint elementBufferObject = 0;

static struct wl_display *display;
static struct wl_registry *registry;
static struct wl_compositor *compositor;
static struct xdg_wm_base *wm_base;
static struct wl_surface *surface;
static struct xdg_surface *xdg_surface;
static struct xdg_toplevel *xdg_toplevel;
static struct wl_callback *frame_callback;
static struct wl_seat *seat;
static struct wl_keyboard *keyboard;

static struct wl_egl_window *egl_window;
static EGLDisplay egl_display;
static EGLContext egl_context;
static EGLSurface egl_surface;

static int win_w = 640;
static int win_h = 480;

static bool running = true;
static bool configured = false;

static float pixel_scale = 12.0f;
// Normalzed Device Cordinates (NDC)
static float ndc_scale = 2.0f;

#define GLYPH_W 5
#define GLYPH_H 7
#define GLYPH_SPACING 1
#define FIRST_CHAR 32
#define LAST_CHAR 126
#define NUM_CHARS (LAST_CHAR - FIRST_CHAR + 1)

static GLuint fontTexture = 0;
static int atlas_w, atlas_h;

struct Glyph {
  const char *rows[GLYPH_H];
};

static struct Glyph font5x7[128];

static void create_font_atlas() {
  atlas_w = NUM_CHARS * (GLYPH_W + GLYPH_SPACING);
  atlas_h = GLYPH_H;
  unsigned char *img = calloc(atlas_w * atlas_h, 1);

  for (int c = FIRST_CHAR; c <= LAST_CHAR; ++c) {
    struct Glyph *g = &font5x7[c];
    int xoff = (c - FIRST_CHAR) * (GLYPH_W + GLYPH_SPACING);
    for (int y = 0; y < GLYPH_H; ++y) {
      for (int x = 0; x < GLYPH_W; ++x) {
        if (g->rows[0]) { // defined glyph?
          char bit = g->rows[y][x];
          img[y * atlas_w + xoff + x] = (bit == '1') ? 255 : 0;
        }
      }
    }
  }

  glGenTextures(1, &fontTexture);
  glBindTexture(GL_TEXTURE_2D, fontTexture);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, atlas_w, atlas_h, 0, GL_RED,
               GL_UNSIGNED_BYTE, img);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  free(img);
}

static void get_glyph_uv(char c, float *u0, float *v0, float *u1, float *v1) {
  if (c < FIRST_CHAR || c > LAST_CHAR)
    c = ' ';
  int idx = c - FIRST_CHAR;
  int xoff = idx * (GLYPH_W + GLYPH_SPACING);
  *u0 = (float)xoff / atlas_w;
  *u1 = (float)(xoff + GLYPH_W) / atlas_w;
  *v0 = 0.0f;
  *v1 = (float)GLYPH_H / atlas_h;
}

void draw_string(const char *text, float x_ndc, float y_ndc, float scale) {
  glBindTexture(GL_TEXTURE_2D, fontTexture);

  float cursor = x_ndc;
  for (int i = 0; text[i]; ++i) {
    float u0, v0, u1, v1;
    get_glyph_uv(text[i], &u0, &v0, &u1, &v1);

    float w = (GLYPH_W * scale) / (float)win_w * ndc_scale;
    float h = (GLYPH_H * scale) / (float)win_h * ndc_scale;

    float x0 = cursor;
    float x1 = cursor + w;
    float y0 = y_ndc;
    float y1 = y_ndc + h;

    GLfloat verts[] = {
        x0, y0, u0, v1, x1, y0, u1, v1, x0, y1, u0, v0, x1, y1, u1, v0,
    };

    glBindBuffer(GL_ARRAY_BUFFER, vertextBufferObject);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(verts), verts);
    glBindVertexArray(vertexArrayObject);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

    float spacing = (GLYPH_SPACING * scale) / (float)win_w * ndc_scale;
    cursor += w + spacing;
  }
}

// 5x7 monospace glyphs for only the letters we need: S, c, r, i, b, e
// Each row is 5 chars '0'/'1'; 7 rows per glyph; 1 column spacing between
// glyphs.
static void init_font() {
  // Uppercase S (5x7)
  font5x7['S'] = (struct Glyph){
      {"01110", "10001", "10000", "01110", "00001", "10001", "01110"}};
  // Lowercase c
  font5x7['c'] = (struct Glyph){
      {"00000", "00000", "01110", "10000", "10000", "10001", "01110"}};
  // Lowercase r
  font5x7['r'] = (struct Glyph){
      {"00000", "00000", "10110", "11001", "10000", "10000", "10000"}};
  // Lowercase i
  font5x7['i'] = (struct Glyph){
      {"00100", "00000", "01100", "00100", "00100", "00100", "01110"}};
  // Lowercase b
  font5x7['b'] = (struct Glyph){
      {"10000", "10000", "11110", "10001", "10001", "10001", "11110"}};
  // Lowercase e
  font5x7['e'] = (struct Glyph){
      {"00000", "00000", "01110", "10001", "11111", "10000", "01110"}};
}

static char *load_file(const char *path) {
  FILE *f = fopen(path, "rb");
  if (!f) {
    fprintf(stderr, "Failed to open: %s\n", path);
    return NULL;
  }
  fseek(f, 0, SEEK_END);
  long len = ftell(f);
  rewind(f);

  char *buf = malloc(len + 1);
  if (!buf) {
    fprintf(stderr, "Out of memory reading: %s\n", path);
    fclose(f);
    return NULL;
  }

  fread(buf, 1, len, f);
  buf[len] = '\0'; // Null-terminate
  fclose(f);
  return buf;
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

static GLuint compile_shader_from(GLenum type, const char *path) {
  char *src = load_file(path);
  GLuint shader = compile_shader(type, src);
  free(src);
  return shader;
}

static void init_shaders() {
  GLuint vs = compile_shader_from(GL_VERTEX_SHADER, "shaders/vertex.glsl");
  GLuint fs = compile_shader_from(GL_FRAGMENT_SHADER, "shaders/fragment.glsl");

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
}

static void setup_buffers() {
  glGenVertexArrays(1, &vertexArrayObject);
  glBindVertexArray(vertexArrayObject);

  glGenBuffers(1, &vertextBufferObject);
  glBindBuffer(GL_ARRAY_BUFFER, vertextBufferObject);
  glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 16, NULL, GL_DYNAMIC_DRAW);

  glGenBuffers(1, &elementBufferObject);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementBufferObject);

  static const GLuint quad_indices[] = {0, 1, 2, 2, 1, 3};
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(quad_indices), quad_indices,
               GL_STATIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 4,
                        (GLvoid *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 4,
                        (GLvoid *)(sizeof(GLfloat) * 2));

  glBindVertexArray(0);

  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

static void draw_frame() {
  glViewport(0, 0, win_w, win_h);
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgram(program);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, fontTexture);

  GLint loc = glGetUniformLocation(program, "uTex");
  if (loc >= 0)
    glUniform1i(loc, 0);

  draw_string("Scribe", -0.7f, 0.0f, pixel_scale);

  eglSwapBuffers(egl_display, egl_surface);
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

  draw_frame();
  schedule_next_frame_and_commit();
}

static void xdg_surface_configure(void *data, struct xdg_surface *xs,
                                  uint32_t serial) {
  xdg_surface_ack_configure(xs, serial);
  if (!configured) {
    configured = true;
    draw_frame();
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
    if (egl_window) {
      wl_egl_window_resize(egl_window, win_w, win_h, 0, 0);
      glBindVertexArray(vertexArrayObject);
      glBindVertexArray(0);
    }
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
                             EGL_OPENGL_ES3_BIT_KHR,
                             EGL_NONE};
  EGLConfig config;
  EGLint n = 0;
  if (!eglChooseConfig(egl_display, config_attribs, &config, 1, &n) || n == 0) {
    fprintf(stderr, "eglChooseConfig failed\n");
    exit(1);
  }

  if (!eglBindAPI(EGL_OPENGL_ES_API)) {
    fprintf(stderr, "eglBindAPI(EGL_OPENGL_ES_API) failed\n");
    exit(1);
  }

  EGLint ctx_attribs[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
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
  setup_buffers();
  init_font();
  create_font_atlas();

  while (running && wl_display_dispatch(display) != -1) {
    // noop
  }

  return 0;
}
