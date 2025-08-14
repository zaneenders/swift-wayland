extension WaylandClientSession {

    struct State: ~Copyable {

        private var wayland_current_object_id: UInt32 = 1

        let wayland_display_object_id: UInt32 = 1
        var wayland_wl_registry_id: UInt32? = nil

        var wl_seat_object_id: UInt32? = nil
        var wl_shm_object_id: UInt32? = nil
        var wl_xdg_wm_base_object_id: UInt32? = nil
        var wl_compositor_object_id: UInt32? = nil
        var wl_surface_object_id: UInt32? = nil
        var xdg_surface_object_id: UInt32? = nil
        var xdg_top_surface_id: UInt32? = nil

        var height: Int = 800
        var width: Int = 600
        var shared_canvas: Canvas

        init() {
            self.shared_canvas = Canvas(pixels: self.height * self.width * 4 * 2)
        }

        private(set) var pool_id: UInt32? = nil
        mutating func setPool(_ pool_id: UInt32) {
            self.pool_id = pool_id
        }

        var frame_counter = 0

        var pixels: Int {
            self.height * self.width * 4
        }

        mutating func nextId() -> UInt32 {
            self.wayland_current_object_id += 1
            return self.wayland_current_object_id
        }

        mutating func update(_ interface_name: String, _ object: UInt32) {
            switch interface_name {
            case "wl_seat":
                self.wl_seat_object_id = object
            case "wl_shm":
                self.wl_shm_object_id = object
            case "xdg_wm_base":
                self.wl_xdg_wm_base_object_id = object
            case "wl_compositor":
                self.wl_compositor_object_id = object
            default:
                ()
            }
        }

        var surfaceComplete: Bool {
            self.xdg_top_surface_id != nil && self.xdg_surface_object_id != nil && self.wl_surface_object_id != nil
        }

        var bindComplete: Bool {
            self.wl_surface_object_id == nil && self.wl_compositor_object_id != nil && self.wl_shm_object_id != nil
                && self.wl_xdg_wm_base_object_id != nil
        }
    }
}
