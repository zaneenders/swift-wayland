extension WaylandClientSession {

    struct State: ~Copyable {
        private var wayland_current_object_id: UInt32 = 1
        var objects = WaylandObjects()
        var shared_canvas: Canvas

        var _height: Int = 800
        var _width: Int = 1280

        let screen_height: UInt32 = 800
        let screen_width: UInt32 = 1280

        let scale: UInt32 = 2
        let stride: UInt32 = 4

        let bufferWidth: UInt32
        let bufferHeight: UInt32
        let bufferBytes: UInt32
        let poolSize: UInt32
        var side: Side? = nil
        var lastFrame = ContinuousClock.now.advanced(by: .milliseconds(-100))

        init() {
            self.objects[1] = .wayland(.display)
            self.bufferWidth = screen_width * scale
            self.bufferHeight = screen_height * scale
            self.bufferBytes = bufferWidth * bufferHeight * stride
            self.poolSize = bufferBytes * 2
            self.shared_canvas = Canvas(bytes: Int(self.poolSize), scale: Int(scale))
        }

        mutating func nextId() -> UInt32 {
            // TODO: solve wrap around
            self.wayland_current_object_id += 1
            return self.wayland_current_object_id
        }

        mutating func update(_ interface_name: String, _ object: UInt32) {
            switch interface_name {
            case "wl_seat":
                self.objects[.wayland(.seat)] = object
            case "wl_shm":
                self.objects[.wayland(.shm)] = object
            case "xdg_wm_base":
                self.objects[.wayland(.xdg_wm_base)] = object
            case "wl_compositor":
                self.objects[.wayland(.compositor)] = object
            case "wl_output":
                self.objects[.wayland(.output)] = object
            default:
                ()
            }
        }

        var surfaceComplete: Bool {
            self.objects[.xdg(.top_surface)] != nil
                && self.objects[.xdg(.surface)] != nil
                && self.objects[.wayland(.surface)] != nil
        }

        var bindComplete: Bool {
            self.objects[.wayland(.surface)] == nil
                && self.objects[.wayland(.compositor)] != nil
                && self.objects[.wayland(.shm)] != nil
                && self.objects[.wayland(.xdg_wm_base)] != nil
        }
    }
}
