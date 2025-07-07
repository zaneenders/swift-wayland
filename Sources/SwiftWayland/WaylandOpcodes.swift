// TODO: group and organize these better.
enum WaylandOpCodes {
    case get_registry
    case registry_event_global
    case wayland_wl_display_error_event
    case wayland_wl_registry_bind_opcode

    var value: UInt16 {
        switch self {
        case .get_registry: 1
        case .registry_event_global: 0
        case .wayland_wl_display_error_event: 0
        case .wayland_wl_registry_bind_opcode: 0
        }
    }
}
