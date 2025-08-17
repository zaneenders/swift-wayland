// TODO: group and organize these better.
enum WaylandOpCodes {
    case error
    case get_registry
    case registry_event_global
    case wayland_wl_display_error_event
    case wayland_wl_registry_bind_opcode
    case wayland_wl_compositor_create_surface_opcode
    case wayland_xdg_wm_base_get_xdg_surface_opcode
    case wayland_xdg_surface_get_toplevel_opcode
    case wayland_wl_surface_commit_opcode
    case wayland_xdg_surface_event_configure
    case wayland_xdg_surface_ack_configure_opcode
    case wayland_wl_shm_create_pool_opcode
    case wayland_xdg_wm_base_event_ping
    case wayland_xdg_wm_base_event_pong

    var value: UInt16 {
        switch self {
        case .error: 0
        case .get_registry: 1
        case .registry_event_global: 0
        case .wayland_wl_display_error_event: 0
        case .wayland_wl_registry_bind_opcode: 0
        case .wayland_wl_compositor_create_surface_opcode: 0
        case .wayland_xdg_wm_base_get_xdg_surface_opcode: 2
        case .wayland_xdg_surface_get_toplevel_opcode: 1
        case .wayland_wl_surface_commit_opcode: 6
        case .wayland_xdg_surface_event_configure: 0
        case .wayland_xdg_surface_ack_configure_opcode: 4
        case .wayland_wl_shm_create_pool_opcode: 0
        case .wayland_xdg_wm_base_event_ping: 0
        case .wayland_xdg_wm_base_event_pong: 2
        }
    }
}

enum WlSurfaceOpCodes: UInt16 {
    case enter = 5
    case leave = 6
}
