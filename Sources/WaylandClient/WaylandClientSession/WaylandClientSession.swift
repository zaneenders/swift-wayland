import Foundation
import NIOCore
import NIOPosix

actor WaylandClientSession {
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
    internal func setupPhase() async throws {
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
    internal func handle(message: WaylandMessage) async throws {
        switch message.object {
        case self.state.wayland_display_object_id:
            switch message.opcode {
            case WaylandOpCodes.error.value:
                var contents = message.message!
                let errorMessage = contents.readString(length: roundup4(contents.readableBytes))
                print("Fatal wl_display error: \(String(describing: errorMessage)). Terminating.")
                return
            case 1:
                var contents = message.message!
                guard let id = contents.readInteger(endianness: .little, as: UInt32.self) else {
                    print("Invalid sync integer: \(String(describing: message.message))")
                    return
                }
                print("Callback[\(id)] finished.")
            default:
                print(
                    "wayland_display_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))"
                )
            }
        case self.state.wayland_wl_registry_id:
            try await registryEvent(message)
        case self.state.wl_seat_object_id:
            print("wl_seat_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
        case self.state.wl_shm_object_id:
            print("wl_shm_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
        case self.state.wl_xdg_wm_base_object_id:
            switch message.opcode {
            case WaylandOpCodes.wayland_xdg_wm_base_event_ping.value:
                var copy = message.message!
                guard let serial = copy.readInteger(endianness: .little, as: UInt32.self) else {
                    print("xdg_wm_base ping: missing serial")
                    return
                }
                print("Sending pong for serial: \(serial)")
                try await xdgPing(serial: serial)
            default:
                print(
                    "wl_xdg_wm_base_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))"
                )
            }
        case self.state.wl_compositor_object_id:
            print(
                "wl_compositor_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
        case self.state.wl_output_object_id:
            switch message.opcode {
            case 1:
                guard var contents = message.message else {
                    print("faliled to read message for \(1)")
                    return
                }
                guard let a = contents.readInteger(endianness: .little, as: UInt32.self),
                    let b = contents.readInteger(endianness: .little, as: UInt32.self),
                    let c = contents.readInteger(endianness: .little, as: UInt32.self),
                    let d = contents.readInteger(endianness: .little, as: UInt32.self)
                else {
                    print("unable to decode mode.")
                    return
                }
                print("output mode: ", a, b, c, d)
            case 2:
                print("output recieved")
            case 3:
                guard var contents = message.message else {
                    print("faliled to read message for \(1)")
                    return
                }
                let scale = contents.readInteger(endianness: .little, as: UInt32.self)
                print("output scale: ", scale as Any)
            default:
                print(
                    "wl_output_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
            }
        case self.state.wl_surface_object_id:
            print("wl_surface_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
        case self.state.xdg_surface_object_id:
            switch message.opcode {
            case WaylandOpCodes.wayland_xdg_surface_event_configure.value:
                print("xdg_surface configure event received. Sending ack.")
                var copy = message.message!
                guard let serial = copy.readInteger(endianness: .little, as: UInt32.self) else {
                    print("xdg_surface configure: missing serial")
                    return
                }
                try await xdgSurfaceEvent(serial)

                if self.state.frame_counter == 0 {
                    print("First frame")
                    try await renderNextFrame()
                }
            default:
                print(
                    "xdg_surface_object_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))"
                )
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
                self.state._width = w
                self.state._height = h
                print("xdg_top_surface_id[\(id)]: width: \(width), height: \(height)")
            default:
                print("xdg_top_surface_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
            }
        case self.state.front_buffer_id, self.state.back_buffer_id:
            switch message.opcode {
            case 0:
                print("Buffer \(message.object) released.")
            default:
                print("unhandled buffer opcode: \(message.opcode)")
            }
        case self.state.frame_callback_id:
            switch message.opcode {
            case 0:
                print("Callback[\(message.object)], next frame.")
                try await renderNextFrame()
            default:
                print("Unhandled callback opcode: \(message.opcode)")
            }
        default:
            guard var copy = message.message else {
                print("unhandled: Object: \(message.object), opcode: \(message.opcode), length: \(message.length)")
                return
            }
            var c2 = copy
            let c3 = copy
            let out = """
                unhandled: Object: \(message.object), opcode: \(message.opcode), 
                UInt32: \(String(describing: copy.readInteger(endianness: .little, as: UInt32.self))) \(String(describing: c2.readInteger(endianness: .big, as: UInt32.self)))"
                String: \(c3.description)
                """
            print(out)
        }

        // State transtions
        if !self.state.surfaceComplete && self.state.bindComplete {
            try await setupSurfacePoolAndBuffer()
        }
    }

    /// Sends a pong response to a Wayland compositor's ping event.
    private func xdgPing(serial: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(serial, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_xdg_wm_base_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_wm_base_event_pong.value,
            message: contents
        )
        try await outbound.write(message)
    }

    private func handleWlSurfaceEvent(_ message: WaylandMessage) async throws {
        switch message.opcode {
        case WlSurfaceOpCodes.enter.rawValue:
            var copy = message.message!
            guard let outputId = copy.readInteger(endianness: .little, as: UInt32.self) else {
                print("wl_surface.enter event: missing output ID")
                return
            }
            print("wl_surface.enter event received for output ID: \(outputId)")
        case WlSurfaceOpCodes.leave.rawValue:
            // This is a wl_surface.leave event.
            // The message payload is a wl_output ID.
            var copy = message.message!
            guard let outputId = copy.readInteger(endianness: .little, as: UInt32.self) else {
                print("wl_surface.leave event: missing output ID")
                return
            }
            print("wl_surface.leave event received for output ID: \(outputId)")
        default:
            print("unhandled wl_surface opcode: \(message.opcode)")
        }
    }
}

extension WaylandClientSession {

    internal func renderNextFrame() async throws {
        let prev = self.state.lastFrame.duration(to: ContinuousClock.now)
        print("Elapsed: \(prev)")
        let width = self.state._width
        let height = self.state._height

        let side: Side = self.state.frame_counter % 2 == 0 ? .front : .back
        let bufferId: UInt32 = (side == .front) ? self.state.front_buffer_id! : self.state.back_buffer_id!

        self.state.shared_canvas.draw(
            side, width: width, height: height, scale: Int(self.state.pixel_scale))

        try await wayland_wl_surface_attach(bufferId)
        try await wayland_wl_surface_damage_buffer(width: UInt32(width), height: UInt32(height))

        try await wayland_wl_surface_frame()
        try await wayland_wl_surface_commit()

        self.state.frame_counter += 1
        self.state.lastFrame = ContinuousClock.now
        print(
            "Frame count: \(self.state.frame_counter), width:\(width), height:\(height)"
        )
    }

    private func wayland_wl_surface_frame() async throws {
        let callbackId = self.state.nextId()
        self.state.frame_callback_id = callbackId

        var contents = ByteBuffer()
        contents.writeInteger(callbackId, endianness: .little, as: UInt32.self)

        let wayland_wl_surface_frame_opcode: UInt16 = 3
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_frame_opcode,
            message: contents)

        try await outbound.write(msg)
    }

    private func wayland_wl_destroy_callback(id: UInt32) async throws {
        let msg = WaylandMessage(object: id, opcode: 0)
        try await outbound.write(msg)
        self.state.frame_callback_id = nil
    }

    func setupSurfacePoolAndBuffer() async throws {
        do {
            self.state.wl_surface_object_id = self.state.nextId()
            try await setupSurface(id: self.state.wl_surface_object_id!)
            self.state.xdg_surface_object_id = self.state.nextId()
            try await getXDGSurface(id: self.state.xdg_surface_object_id!)
            self.state.xdg_top_surface_id = self.state.nextId()
            try await xdgGetTopSurface(id: self.state.xdg_top_surface_id!)
            try await surfaceCommit()

            print("Bind State Complete")

            let pool_size = self.state.shared_canvas.size
            let half = self.state.shared_canvas.half

            let pool_id = try await createPool(
                fd: Int(self.state.shared_canvas.fd),
                buffer_size: UInt32(pool_size))
            self.state.setPool(pool_id)

            let front = try await poolCreateBuffer(
                self.state.pool_id!,
                offset: 0,
                width: UInt32(self.state.screen_width),
                height: UInt32(self.state.screen_height))
            self.state.set(front: front)

            let back = try await poolCreateBuffer(
                self.state.pool_id!,
                offset: UInt32(half),
                width: UInt32(self.state.screen_width),
                height: UInt32(self.state.screen_height))
            self.state.set(back: back)
        } catch {
            print(error)
            throw WaylandSetupError.unableToSetupSurface
        }
        print("Surface setup Complete")
    }

    func registryEvent(_ message: WaylandMessage) async throws {
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
                case "wl_seat", "wl_shm", "xdg_wm_base", "wl_compositor", "wl_output":
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
            print("wayland_wl_registry_id[\(message.object)]: \(message.opcode) \(String(describing: message.message))")
        }
    }

    private func wayland_wl_destroy_buffer(
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

    private func wayland_wl_surface_commit()
        async throws
    {
        let wayland_wl_surface_commit_opcode: UInt16 = 6
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_commit_opcode)
        try await outbound.write(msg)
    }

    private func wayland_wl_surface_damage_buffer(width: UInt32, height: UInt32)
        async throws
    {
        var contents = ByteBuffer()
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(width, endianness: .little, as: UInt32.self)
        contents.writeInteger(height, endianness: .little, as: UInt32.self)
        let wayland_wl_surface_damage_buffer_opcode: UInt16 = 9
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_damage_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
    }

    private func wayland_wl_surface_set_buffer_scale2() async throws {
        var contents = ByteBuffer()
        contents.writeInteger(2, endianness: .little, as: UInt32.self)
        let wayland_wl_surface_frame_opcode: UInt16 = 8
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_frame_opcode,
            message: contents)
        try await outbound.write(msg)
    }

    private func wayland_wl_surface_attach(
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

    private func poolCreateBuffer(
        _ pool_id: UInt32, offset: UInt32, width: UInt32, height: UInt32
    ) async throws
        -> UInt32
    {
        var contents = ByteBuffer()
        let bufferId = self.state.nextId()
        contents.writeInteger(bufferId, endianness: .little, as: UInt32.self)
        contents.writeInteger(offset, endianness: .little, as: UInt32.self)
        contents.writeInteger(width, endianness: .little, as: UInt32.self)
        contents.writeInteger(height, endianness: .little, as: UInt32.self)
        let stride: UInt32 = 4 * width
        contents.writeInteger(stride, endianness: .little, as: UInt32.self)
        let wayland_format_argb8888: UInt32 = 0
        contents.writeInteger(wayland_format_argb8888, endianness: .little, as: UInt32.self)

        let wayland_wl_shm_pool_create_buffer_opcode: UInt16 = 0
        let msg = WaylandMessage(
            object: pool_id,
            opcode: wayland_wl_shm_pool_create_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
        return bufferId
    }

    private func createPool(fd: Int, buffer_size: UInt32) async throws -> UInt32 {
        var contents = ByteBuffer()
        let pool_id = self.state.nextId()
        contents.writeInteger(pool_id, endianness: .little, as: UInt32.self)
        contents.writeInteger(buffer_size, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_shm_object_id!,
            opcode: WaylandOpCodes.wayland_wl_shm_create_pool_opcode.value,
            message: contents,
            fd: fd)
        try await outbound.write(message)
        return pool_id
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

    private func getXDGSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        contents.writeInteger(self.state.wl_surface_object_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_xdg_wm_base_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_wm_base_get_xdg_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private func setupSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_compositor_object_id!,
            opcode: WaylandOpCodes.wayland_wl_compositor_create_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private func xdgSurfaceEvent(_ value: UInt32) async throws {
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
