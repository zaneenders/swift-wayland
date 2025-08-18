import Logging

enum LoggingMetadataTag: CustomStringConvertible {
    case render
    var description: String {
        "render"
    }
}

struct SessionLogHandler: LogHandler {

    var metadata: Logging.Logger.Metadata = [:]
    var logLevel: Logging.Logger.Level

    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            metadata[key]
        }
        set(newValue) {
            metadata[key] = newValue
        }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        if let m = metadata {
            if m[LoggingMetadataTag.render.description] != nil {
                return
            }
        }
        print("[\(level)]\(message)")
    }
}
