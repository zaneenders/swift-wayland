extension WaylandClientSession {

    struct State: ~Copyable {

        private var wayland_current_object_id: UInt32 = 1

        let wayland_display_object_id: UInt32 = 1
        var wayland_wl_registry_id: UInt32? = nil

        var wl_seat_object_id: UInt32? = nil
        var wl_shm_object_id: UInt32? = nil
        var wl_xdg_wm_base_object_id: UInt32? = nil
        var wl_compositor_object_id: UInt32? = nil
        var wl_output_object_id: UInt32? = nil
        var wl_surface_object_id: UInt32? = nil
        var xdg_surface_object_id: UInt32? = nil
        var xdg_top_surface_id: UInt32? = nil

        var _height: Int = 800
        var _width: Int = 1280
        var shared_canvas: Canvas

        let screen_height: UInt32 = 800
        let screen_width: UInt32 = 1280

        let scale: UInt32 = 2
        let stride: UInt32 = 4

        let bufferWidth: UInt32
        let bufferHeight: UInt32
        let bufferBytes: UInt32
        let poolSize: UInt32
        var side: Side? = nil

        init() {
            self.bufferWidth = screen_width * scale
            self.bufferHeight = screen_height * scale
            self.bufferBytes = bufferWidth * bufferHeight * stride
            self.poolSize = bufferBytes * 2
            self.shared_canvas = Canvas(bytes: Int(self.poolSize), scale: Int(scale))
        }

        private(set) var pool_id: UInt32? = nil
        mutating func setPool(_ pool_id: UInt32) {
            self.pool_id = pool_id
        }

        private(set) var back_buffer_id: UInt32? = nil
        mutating func set(back buffer: UInt32) {
            self.back_buffer_id = buffer
        }

        var frame_callback_id: UInt32? = nil
        private(set) var front_buffer_id: UInt32? = nil
        mutating func set(front buffer: UInt32) {
            self.front_buffer_id = buffer
        }

        var lastFrame = ContinuousClock.now.advanced(by: .milliseconds(-100))

        mutating func nextId() -> UInt32 {
            // TODO: solve wrap around
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
            case "wl_output":
                self.wl_output_object_id = object
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
