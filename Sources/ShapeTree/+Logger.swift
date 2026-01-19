import Logging

extension Logger {
  public static func create(logLevel: Logger.Level, label: String = #function) -> Logger {
    return {
      var _logger = Logger(label: label)
      _logger.logLevel = logLevel
      return _logger
    }()
  }
}
