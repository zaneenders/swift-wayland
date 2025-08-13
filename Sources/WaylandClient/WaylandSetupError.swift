enum WaylandSetupError: Error {
    case xdg_runtime_dir
    case badFD
    case connect
}
