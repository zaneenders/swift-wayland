enum WaylandSetupError: Error {
    case xdg_runtime_dir
    case badFD
    case connect
    case unableToSetupSurface
}

enum WaylandShutdownError: Error {
    case shutdown
}
