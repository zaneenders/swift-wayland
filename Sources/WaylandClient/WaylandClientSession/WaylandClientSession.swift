import Foundation
import NIOCore
import NIOPosix

struct WaylandClientSession: ~Copyable {
    private let outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    private var state: State = State()

    internal init(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) {
        self.outbound = outbound
    }
}

// MARK: Setup
extension WaylandClientSession {

    /// Called before messages are recieved.
    /// Setus up iniital state and connection phase
    internal mutating func setupPhase() async throws {
        self.state.wayland_wl_registry_id = self.state.nextId()
        try await setupRegistry(id: self.state.wayland_wl_registry_id!)
    }

    private func setupRegistry(id: UInt32) async throws {
        // Setup regisstry
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wayland_display_object_id,
            opcode: WaylandOpCodes.get_registry.value,
            message: contents)
        try await outbound.write(message)
    }
}

// MARK: Message
extension WaylandClientSession {

    /// Responsible for handling each message
    internal mutating func handle(message: WaylandMessage) async throws {
        switch message.object {
        case self.state.wayland_display_object_id:
            displayObjectEvent(message)
        case self.state.wayland_wl_registry_id:
            try await registryEvent(message)
        case self.state.wl_xdg_wm_base_object_id:
            switch message.opcode {
            case WaylandOpCodes.wayland_xdg_wm_base_event_ping.value:
                print("TODO: send pong")
            default:
                print("Unknown wl_xdg_wm_base_object_id message, opcode: \(message.opcode)")
            }
        case self.state.xdg_top_surface_id:
            switch message.opcode {
            case 0:
                let id = self.state.xdg_top_surface_id!
                guard var contents = message.message else {
                    print("xdg_top_surface_id[\(id)]: failed")
                    return
                }
                guard let width = contents.readInteger(endianness: .little, as: UInt32.self) else {
                    print("xdg_top_surface_id[\(id)]: failed, width")
                    return
                }
                guard let height = contents.readInteger(endianness: .little, as: UInt32.self) else {
                    print("xdg_top_surface_id[\(id)]: failed, height")
                    return
                }
                let w = Int(width)
                let h = Int(height)
                self.state.size_did_change = (self.state.width != w || self.state.height != h)
                self.state.width = w
                self.state.height = h
                print("xdg_top_surface_id[\(id)]: \(width), \(height)")
            default:
                print("Unknown: xdg_top_surface_id")
            }
        case self.state.xdg_surface_object_id:
            switch message.opcode {
            case WaylandOpCodes.wayland_xdg_surface_event_configure.value:
                var copy = message.message!
                do {
                    try await renderFrame(height: self.state.height, width: self.state.width)
                } catch {
                    print(error)
                }
            default:
                print("Unknown: xdg_surface_object_id")
            }
        default:
            // BUG: still a data race here use a mutex
            if let found = self.state.watch[message.object] {
                print("KEY: \(message.object), FOUND: \(found)")
                if self.state.size_did_change {
                    self.state.size_did_change = false

                    print("Size change new buffer")
                    let front_buffer_id = try await poolCreateBuffer(
                        self.state.pool_id!, offset: 0,
                        width: UInt32(self.state.width),
                        height: UInt32(self.state.height))
                    self.state.set(front_buffer_id)

                    self.state.shared_canvas.resize(pixels: self.state.height * self.state.width * 4)
                    try await _release_buffer(found)
                }
                self.state.watch.removeValue(forKey: message.object)
                return
            }

            guard var copy = message.message else {
                print("unhandled: Object: \(message.object), opcode: \(message.opcode), length: \(message.length)")
                return
            }
            var c2 = copy
            let c3 = copy
            let out = """
                unhandled: Object: \(message.object), opcode: \(message.opcode), 
                UInt32: \(copy.readInteger(endianness: .little, as: UInt32.self)) \(c2.readInteger(endianness: .big, as: UInt32.self))"
                String: \(c3.description)
                """
            print(out)
        }

        // State transtions
        if !self.state.surfaceComplete && self.state.bindComplete {
            do {
                self.state.wl_surface_object_id = self.state.nextId()
                try await setupSurface(id: self.state.wl_surface_object_id!)
                self.state.xdg_surface_object_id = self.state.nextId()
                try await getXDGSurface(id: self.state.xdg_surface_object_id!)
                self.state.xdg_top_surface_id = self.state.nextId()
                try await xdgGetTopSurface(id: self.state.xdg_top_surface_id!)
                try await surfaceCommit()
                try await xdgSurfaceEvent(self.state.xdg_top_surface_id!)
                print("Bind State Complete")
                let pool_id = try await createPool(
                    fd: Int(self.state.shared_canvas.fd), pixels: UInt32(self.state.pixels * 2))
                self.state.setPool(pool_id)
                let buffer_id = try await poolCreateBuffer(
                    self.state.pool_id!, offset: 0, width: UInt32(self.state.width), height: UInt32(self.state.height))
                self.state.set(buffer_id)
            } catch {
                print(error)
                throw WaylandSetupError.unableToSetupSurface
            }
            print("Surface setup Complete")
        }
    }

    private mutating func renderFrame(height: Int, width: Int) async throws {
        guard self.state.watch.isEmpty else {
            print("Frame skipped")
            return
        }
        self.state.shared_canvas.draw(self.state.frame_counter, height: height, width: width)
        try await _render(self.state.buffer_id!)
        self.state.frame_counter += 1
        print("Frame count: \(self.state.frame_counter)")
    }

    mutating func _render(_ buffer_id: UInt32) async throws {
        try await wayland_wl_surface_attach(buffer_id)
        try await wayland_wl_surface_damage_buffer()
        try await wayland_wl_surface_commit()
        let callback = self.state.nextId()
        print("callback: \(callback), buffer_id: \(buffer_id)")
        self.state.watch[callback] = buffer_id
        try await wayland_wl_surface_frame(callback)
    }

    private mutating func displayObjectEvent(_ message: WaylandMessage) {
        guard message.object == self.state.wayland_display_object_id else {
            return
        }
        switch message.opcode {
        case WaylandOpCodes.wayland_wl_display_error_event.value:
            if let error_message = message.message {
                print(
                    "wl_display: Error",
                    error_message.getString(at: 0, length: Int(message.length - WaylandMessage.headerSize)))
            } else {
                print("wl_display: Error", message.length)
            }
        default:
            ()
        }
    }

    mutating func registryEvent(_ message: WaylandMessage) async throws {
        guard message.object == self.state.wayland_wl_registry_id else {
            return
        }
        switch message.opcode {
        case WaylandOpCodes.registry_event_global.value:
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
                    let id = self.state.nextId()
                    try await self.sendBind(
                        registry: message.object, id: id, name: name,
                        interface_name: interface_name, verison: verison)
                    self.state.update(interface_name, id)
                default:
                    print(
                        "wl_registry:unhandled", message.object, message.opcode, message.length, name,
                        interface_name,
                        verison)
                }
            } catch {
                print(interface_name, error, type(of: error))
            }
        default:
            ()
        }
    }

    private func surfaceCommit() async throws {
        let message = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: WaylandOpCodes.wayland_wl_surface_commit_opcode.value)
        try await outbound.write(message)
    }

    private func xdgGetTopSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(self.state.xdg_top_surface_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_surface_get_toplevel_opcode.value, message: contents)
        try await outbound.write(message)
        print("Top level surface id = \(self.state.xdg_top_surface_id!)")
    }

    private mutating func getXDGSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        contents.writeInteger(self.state.wl_surface_object_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_xdg_wm_base_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_wm_base_get_xdg_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func setupSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_compositor_object_id!,
            opcode: WaylandOpCodes.wayland_wl_compositor_create_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func _release_buffer(
        _ buffer_id: UInt32
    ) async throws {
        //  store_old_id(state->old_wl_buffers, &state->old_wl_buffers_len, wl_buffer);
        try await _wayland_wl_destroy_buffer(buffer_id)
    }

    private mutating func _wayland_wl_destroy_buffer(
        _ buffer_id: UInt32
    )
        async throws
    {
        let wayland_wl_buffer_destroy_opcode: UInt16 = 0
        let msg = WaylandMessage(
            object: buffer_id,
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

    private mutating func wayland_wl_surface_frame(_ buffer: UInt32) async throws {
        // #define WL_SURFACE_FRAME 3
        var contents = ByteBuffer()
        contents.writeInteger(buffer, endianness: .little, as: UInt32.self)
        let wayland_wl_surface_frame_opcode: UInt16 = 3
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_frame_opcode,
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

    private mutating func poolCreateBuffer(
        _ pool_id: UInt32, offset: UInt32, width: UInt32, height: UInt32
    ) async throws
        -> UInt32
    {
        var contents = ByteBuffer()
        let bufferId = self.state.nextId()
        contents.writeInteger(bufferId, endianness: .little, as: UInt32.self)
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
            object: pool_id,
            opcode: wayland_wl_shm_pool_create_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
        return bufferId
    }

    private mutating func createPool(fd: Int, pixels: UInt32) async throws -> UInt32 {
        var contents = ByteBuffer()
        let pool_id = self.state.nextId()
        contents.writeInteger(pool_id, endianness: .little, as: UInt32.self)
        contents.writeInteger(pixels, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_shm_object_id!,
            opcode: WaylandOpCodes.wayland_wl_shm_create_pool_opcode.value,
            message: contents,
            fd: fd)
        try await outbound.write(message)
        return pool_id
    }

    private mutating func xdgSurfaceEvent(_ value: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(value, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_surface_ack_configure_opcode.value,
            message: contents)
        try await outbound.write(message)
    }

    private func sendBind(registry: UInt32, id: UInt32, name: UInt32, interface_name: String, verison: UInt32)
        async throws
    {
        var contents = ByteBuffer()
        let out = interface_name.getRounded()
        contents.writeInteger(name, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(out.count), endianness: .little, as: UInt32.self)
        contents.writeString(out)
        contents.writeInteger(verison, endianness: .little, as: UInt32.self)
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: registry,
            opcode: WaylandOpCodes.wayland_wl_registry_bind_opcode.value,
            message: contents)
        try await outbound.write(message)
    }
}
