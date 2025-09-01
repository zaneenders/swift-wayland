
#include "xdg-shell-client-protocol.h"
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

// Client-side state struct to hold essential Wayland objects.
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
};

// Listeners for Wayland events.
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
}

static void xdg_toplevel_close(void *data, struct xdg_toplevel *toplevel) {
  struct client_state *state = data;
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

// Define a listener for wl_callback
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

  // Request the first frame callback to start the animation loop.
  struct wl_callback *callback = wl_surface_frame(state->wl_surface);
  wl_callback_add_listener(callback, &frame_listener, state);

  draw_frame(state);

  // Commit to make the callback request active.
  wl_surface_commit(state->wl_surface);
}

// Main rendering function that you will call for each frame
void draw_frame(struct client_state *state) {
  // We'll reuse the buffer logic, but modify the content for animation.
  struct wl_buffer *buffer;
  int stride = state->width * 4;
  int size = stride * state->height;

  int fd = shm_open("/wayland-client", O_CREAT | O_RDWR, 0600);
  if (fd < 0) {
    perror("shm_open");
    return;
  }
  shm_unlink("/wayland-client");
  if (fd == -1) {
    perror("memfd_create");
    return;
  }
  ftruncate(fd, size);
  uint32_t *data_ptr =
      mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (data_ptr == MAP_FAILED) {
    perror("mmap");
    close(fd);
    return;
  }

  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);

  uint32_t color = (ts.tv_nsec / 1000000) % 255;
  uint32_t current_color = 0xFF000000 | (color << 16) | (color << 8) | color;

  for (int y = 0; y < state->height; ++y) {
    for (int x = 0; x < state->width; ++x) {
      data_ptr[y * state->width + x] = current_color;
    }
  }

  struct wl_shm_pool *pool = wl_shm_create_pool(state->wl_shm, fd, size);
  buffer = wl_shm_pool_create_buffer(pool, 0, state->width, state->height,
                                     stride, WL_SHM_FORMAT_ARGB8888);

  wl_surface_attach(state->wl_surface, buffer, 0, 0);
  wl_surface_damage_buffer(state->wl_surface, 0, 0, state->width,
                           state->height);

  struct wl_callback *callback = wl_surface_frame(state->wl_surface);
  wl_callback_add_listener(callback, &frame_listener, state);

  wl_surface_commit(state->wl_surface);

  munmap(data_ptr, size);
  close(fd);
  wl_shm_pool_destroy(pool);
  wl_buffer_destroy(buffer);
}

static const struct xdg_surface_listener xdg_surface_listener = {
    .configure = xdg_surface_configure,
};

// The registry listener that binds to key global interfaces.
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
                                          uint32_t name) {}

static const struct wl_registry_listener registry_listener = {
    .global = registry_handle_global,
    .global_remove = registry_handle_global_remove,
};

int main(int argc, char *argv[]) {
  struct client_state state = {0};
  state.width = 800;
  state.height = 600;

  // Connect to the Wayland display.
  state.wl_display = wl_display_connect(NULL);
  if (!state.wl_display) {
    fprintf(stderr, "Failed to connect to Wayland display.\n");
    return 1;
  }

  // Get the registry and listen for global objects.
  struct wl_registry *registry = wl_display_get_registry(state.wl_display);
  wl_registry_add_listener(registry, &registry_listener, &state);
  wl_display_roundtrip(state.wl_display);

  // Check that we found the required interfaces.
  if (!state.wl_compositor || !state.wl_shm || !state.xdg_wm_base) {
    fprintf(stderr, "Failed to find essential Wayland interfaces.\n");
    return 1;
  }

  // Set up the xdg_wm_base listener to handle pings from the compositor.
  xdg_wm_base_add_listener(state.xdg_wm_base, &xdg_wm_base_listener, &state);

  // Create a surface and an xdg_surface from it.
  state.wl_surface = wl_compositor_create_surface(state.wl_compositor);
  state.xdg_surface =
      xdg_wm_base_get_xdg_surface(state.xdg_wm_base, state.wl_surface);
  xdg_surface_add_listener(state.xdg_surface, &xdg_surface_listener, &state);

  // Create a top-level window.
  state.xdg_toplevel = xdg_surface_get_toplevel(state.xdg_surface);
  xdg_toplevel_add_listener(state.xdg_toplevel, &xdg_toplevel_listener, &state);
  xdg_toplevel_set_title(state.xdg_toplevel, "Hello Wayland");

  // Commit the initial state to create the window.
  wl_surface_commit(state.wl_surface);

  // The main event loop.
  while (wl_display_dispatch(state.wl_display) != -1 && !state.closed) {
    wl_display_flush(state.wl_display);
    usleep(1000); // Small delay to prevent busy-waiting
  }

  // Cleanup.
  xdg_toplevel_destroy(state.xdg_toplevel);
  xdg_surface_destroy(state.xdg_surface);
  wl_surface_destroy(state.wl_surface);
  wl_shm_destroy(state.wl_shm);
  xdg_wm_base_destroy(state.xdg_wm_base);
  wl_registry_destroy(registry);
  wl_display_disconnect(state.wl_display);

  return 0;
}
