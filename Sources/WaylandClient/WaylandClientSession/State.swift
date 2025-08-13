extension WaylandClientSession {

    struct State {

        private var wayland_current_object_id: UInt32 = 1

        let wayland_display_object_id: UInt32 = 1
        var wayland_wl_registry_id: UInt32? = nil
        var frame_buffer_fd: Int32!

        var wl_seat_object_id: UInt32? = nil
        var wl_shm_object_id: UInt32? = nil
        var wl_xdg_wm_base_object_id: UInt32? = nil
        var wl_compositor_object_id: UInt32? = nil
        var wl_surface_object_id: UInt32? = nil
        var xdg_surface_object_id: UInt32? = nil
        var xdg_top_surface_id: UInt32? = nil

        var shm_pool_data_pointer: UnsafeMutableRawPointer!
        var pool_id: UInt32? = nil

        var height: Int = 800
        var width: Int = 600

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
