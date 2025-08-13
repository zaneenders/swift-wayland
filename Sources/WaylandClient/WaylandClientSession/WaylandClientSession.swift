import Foundation
import NIOCore
import NIOPosix

typealias FD = Int32

struct WaylandClientSession {

    private let outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    private var state: State = State()

    internal init(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) {
        self.outbound = outbound
    }

    /// Called before messages are recieved.
    /// Setus up iniital state and connection phase
    internal mutating func setupPhase() async throws {
        try await setupRegistry()
        setupFrameBuffer()
    }

    /// Responsible for handling each message
    internal mutating func handle(message: WaylandMessage) async throws {
        await handleWaylandResponse(message)
        if self.state.bindComplete {
            print("Bind State Complete")
            try await setupSurface()
            try await getXDGSurface()
            try await xdgGetTopSurface()
            try await surfaceCommit()
        }
    }
}

extension WaylandClientSession {

    private mutating func setupRegistry() async throws {
        // Setup regisstry
        var contents = ByteBuffer()
        self.state.wayland_current_object_id += 1
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wayland_display_object_id,
            opcode: WaylandOpCodes.get_registry.value,
            message: contents)
        try await outbound.write(message)
        self.state.wayland_wl_registry_id = self.state.wayland_current_object_id
    }

    private mutating func setupFrameBuffer() {
        self.state.frame_buffer_fd = createFrameBuffer()
    }

    private mutating func createFrameBuffer() -> FD {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        _resizeFrameBuffer(shared_fd, size: self.state.pixels)
        return shared_fd
    }

    private mutating func _resizeFrameBuffer(_ fd: FD, size: Int) {
        ftruncate(fd, size)
        self.state.shm_pool_data_pointer = mmap(
            nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        assert(self.state.shm_pool_data_pointer != nil)
    }

    private mutating func surfaceCommit() async throws {
        let message = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: WaylandOpCodes.wayland_wl_surface_commit_opcode.value)
        try await outbound.write(message)
    }

    private mutating func xdgGetTopSurface() async throws {
        var contents = ByteBuffer()
        self.state.wayland_current_object_id += 1
        self.state.xdg_top_surface_id = self.state.wayland_current_object_id
        print("Top level surface id = \(self.state.xdg_top_surface_id!)")
        contents.writeInteger(self.state.xdg_top_surface_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_surface_get_toplevel_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func getXDGSurface() async throws {
        self.state.wayland_current_object_id += 1
        var contents = ByteBuffer()
        self.state.xdg_surface_object_id = self.state.wayland_current_object_id
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        contents.writeInteger(self.state.wl_surface_object_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_xdg_wm_base_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_wm_base_get_xdg_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func setupSurface() async throws {
        self.state.wayland_current_object_id += 1
        var contents = ByteBuffer()
        self.state.wl_surface_object_id = self.state.wayland_current_object_id
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_compositor_object_id!,
            opcode: WaylandOpCodes.wayland_wl_compositor_create_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func handleWaylandResponse(
        _ message: WaylandMessage,
    ) async {
        if message.object == self.state.wayland_display_object_id
            && message.opcode == WaylandOpCodes.wayland_wl_display_error_event.value
        {
            print("wl_display: Error", message.length)
            if let error_message = message.message {
                print(error_message.getString(at: 0, length: Int(message.length - WaylandMessage.headerSize)))
            }
        } else if message.object == self.state.wayland_wl_registry_id
            && message.opcode == WaylandOpCodes.registry_event_global.value
        {
            guard var buffer = message.message,
                let name = buffer.readInteger(endianness: .little, as: UInt32.self),
                let interface_length = buffer.readInteger(endianness: .little, as: UInt32.self),
                let _interface_name = buffer.readString(length: roundup4(Int(interface_length))),
                let verison = buffer.readInteger(endianness: .little, as: UInt32.self)
            else {
                print("wl_registry:: Invalid event")
                return
            }
            // Trim trailing null byte padding
            let end_index = _interface_name.firstIndex(of: "\0") ?? _interface_name.endIndex
            let interface_name = String(_interface_name[_interface_name.startIndex..<end_index])
            do {
                switch interface_name {
                case "wl_seat", "wl_shm", "xdg_wm_base", "wl_compositor":
                    print(
                        "wl_registry:bind object: \(message.object), opcode: \(message.opcode) length: \(message.length), name: \(name), interface_name: \(interface_name), verison: \(verison)"
                    )
                    let id = try await self.bind(
                        registry: message.object,
                        name: name, interface_name: interface_name, verison: verison)
                    self.state.update(interface_name, id)
                default:
                    print(
                        "wl_registry:unhandled", message.object, message.opcode, message.length, name, interface_name,
                        verison)
                    ()
                }
            } catch {
                print(interface_name, error, type(of: error))
            }
        } else if message.object == self.state.wl_xdg_wm_base_object_id
            && message.opcode == WaylandOpCodes.wayland_xdg_wm_base_event_ping.value
        {
            print("TODO: send pong")
        } else if message.object == self.state.xdg_top_surface_id && message.opcode == 0 {
            guard var contents = message.message else {
                print("maybe resize")
                return
            }
            guard let width = contents.readInteger(endianness: .little, as: UInt32.self) else {
                return
            }
            guard let height = contents.readInteger(endianness: .little, as: UInt32.self) else {
                return
            }
            //self.state.width = Int(width)
            //self.state.height = Int(height)
            // Just ignoring for now
            _resizeFrameBuffer(self.state.frame_buffer_fd, size: self.state.pixels)
            print("xdg_top_surface_id[0]: \(width), \(height)")
        } else if message.object == self.state.xdg_surface_object_id
            && message.opcode == WaylandOpCodes.wayland_xdg_surface_event_configure.value
        {
            var copy = message.message!
            let value = copy.readInteger(as: UInt32.self)!
            do {
                try await xdgSurfaceEvent(value)
                let pool_id = try await createPool()
                self.state.pool_id = pool_id
                try await renderFrame()
            } catch {
                print(error)
            }
        } else {
            if let error_message = message.message {
                print(
                    "Unhandled: \(message)",
                    error_message.getString(at: 0, length: Int(message.length - WaylandMessage.headerSize)))
            } else {
                print("Unhandled: \(message)")
            }
        }
    }

    private mutating func renderFrame() async throws {
        let id = try await poolCreateBuffer()

        let typedPixels = self.state.shm_pool_data_pointer.assumingMemoryBound(to: UInt32.self)
        for i in 0..<self.state.height * self.state.width {
            if i.isMultiple(of: 5) {
                typedPixels[i] = 0xffffff
            } else {
                typedPixels[i] = 0x21b9ff
            }
        }
        try await wayland_wl_surface_attach(id)
        try await wayland_wl_surface_damage_buffer()
        try await wayland_wl_surface_commit()
        try await release_buffer(id)
    }

    private mutating func release_buffer(
        _ id: UInt32
    ) async throws {
        //  store_old_id(state->old_wl_buffers, &state->old_wl_buffers_len, wl_buffer);
        try await wayland_wl_destroy_buffer(id)
    }

    private mutating func wayland_wl_destroy_buffer(
        _ buffer: UInt32
    )
        async throws
    {
        let wayland_wl_buffer_destroy_opcode: UInt16 = 0
        let msg = WaylandMessage(
            object: buffer,
            opcode: wayland_wl_buffer_destroy_opcode)
        try await outbound.write(msg)
    }

    private mutating func wayland_wl_surface_commit()
        async throws
    {
        let wayland_wl_surface_commit_opcode: UInt16 = 6
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_commit_opcode)
        try await outbound.write(msg)
    }

    private mutating func wayland_wl_surface_damage_buffer()
        async throws
    {
        // wayland_wl_surface_damage_buffer(fd, state -> wl_surface, 0, 0, INT32_MAX, INT32_MAX)
        var contents = ByteBuffer()
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(Int32.max), endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(Int32.max), endianness: .little, as: UInt32.self)
        let wayland_wl_surface_damage_buffer_opcode: UInt16 = 9
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_damage_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
    }

    private mutating func wayland_wl_surface_attach(
        _ buffer: UInt32
    )
        async throws
    {
        var contents = ByteBuffer()
        contents.writeInteger(buffer, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        let wayland_wl_surface_attach_opcode: UInt16 = 1
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_attach_opcode,
            message: contents)
        try await outbound.write(msg)
    }

    private mutating func poolCreateBuffer() async throws
        -> UInt32
    {
        var contents = ByteBuffer()
        self.state.wayland_current_object_id += 1
        let id = self.state.wayland_current_object_id
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let offset: UInt32 = 0
        contents.writeInteger(offset, endianness: .little, as: UInt32.self)
        let width: UInt32 = UInt32(self.state.width)
        contents.writeInteger(width, endianness: .little, as: UInt32.self)
        let height: UInt32 = UInt32(self.state.height)
        contents.writeInteger(height, endianness: .little, as: UInt32.self)
        let stride: UInt32 = 4 * width
        contents.writeInteger(stride, endianness: .little, as: UInt32.self)
        let wayland_format_xrgb8888: UInt32 = 1
        contents.writeInteger(wayland_format_xrgb8888, endianness: .little, as: UInt32.self)

        let wayland_wl_shm_pool_create_buffer_opcode: UInt16 = 0
        let msg = WaylandMessage(
            object: self.state.pool_id!,
            opcode: wayland_wl_shm_pool_create_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
        return id
    }

    private mutating func createPool() async throws -> UInt32 {
        assert(self.state.shm_pool_data_pointer != nil)
        var contents = ByteBuffer()
        self.state.wayland_current_object_id += 1
        let pool_id = self.state.wayland_current_object_id
        contents.writeInteger(pool_id, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(self.state.pixels), endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_shm_object_id!,
            opcode: WaylandOpCodes.wayland_wl_shm_create_pool_opcode.value,
            message: contents,
            fd: Int(self.state.frame_buffer_fd!))
        try await outbound.write(message)
        return pool_id
    }

    private mutating func xdgSurfaceEvent(_ value: UInt32) async throws {
        print("TODO: STATE Change")
        var contents = ByteBuffer()
        contents.writeInteger(value, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_surface_ack_configure_opcode.value,
            message: contents)
        try await outbound.write(message)
    }

    private mutating func bind(registry: UInt32, name: UInt32, interface_name: String, verison: UInt32) async throws
        -> UInt32
    {
        var contents = ByteBuffer()
        let out = interface_name.getRounded()
        contents.writeInteger(name, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(out.count), endianness: .little, as: UInt32.self)
        contents.writeString(out)
        contents.writeInteger(verison, endianness: .little, as: UInt32.self)
        self.state.wayland_current_object_id += 1
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: registry,
            opcode: WaylandOpCodes.wayland_wl_registry_bind_opcode.value,
            message: contents)
        try await outbound.write(message)
        return self.state.wayland_current_object_id
    }
}
