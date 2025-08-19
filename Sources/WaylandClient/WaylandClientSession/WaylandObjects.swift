enum NamedObjects: Hashable {
    case other(String)
    case wayland(Wayland)
    case xdg(XDG)
    case frontBuffer
    case backBuffer
    case pool
    case frameCallback

    enum XDG: Hashable {
        case surface
        case top_surface
    }

    enum Wayland: Hashable {
        case display
        case registry
        case seat
        case shm  // shared memory
        case xdg_wm_base
        case compositor
        case output
        case surface
    }
}

struct WaylandObjects {
    private var _objects: [UInt32: NamedObjects] = [:]
    private var _keys: [NamedObjects: UInt32] = [:]

    subscript(_ key: NamedObjects) -> UInt32? {
        get {
            _keys[key]
        }
        set(newValue) {
            if let newValue {
                _keys[key] = newValue
                _objects[newValue] = key
            }
        }
    }

    mutating func removeValue(forKey key: NamedObjects) {
        let object = _keys[key]
        _keys.removeValue(forKey: key)
        _objects.removeValue(forKey: object!)
    }

    subscript(_ object: UInt32) -> NamedObjects? {
        get {
            _objects[object]
        }
        set(newValue) {
            if let newValue {
                _keys[newValue] = object
                _objects[object] = newValue
            }
        }
    }
}
