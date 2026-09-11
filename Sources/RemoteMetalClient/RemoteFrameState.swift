import Chroma
import RemoteProtocol

/// Keeps the last good presentation while allowing another request after a bad
/// frame. Wire decoding must happen first, including image-cache updates.
struct RemoteFrameState {
  private(set) var latest: (viewport: Size, commands: [DrawCommand])?
  var requestOutstanding = false

  @discardableResult
  mutating func receive(_ message: RemoteMessage) -> Bool {
    switch message {
    case .frame(_, _, let viewport, let commands):
      requestOutstanding = false
      guard RemoteFrameValidation.isValid(viewport: viewport, commands: commands) else { return false }
      latest = (viewport, commands)
      return true
    case .frameUnchanged:
      requestOutstanding = false
      return false
    default:
      return false
    }
  }
}
