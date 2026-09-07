import Foundation

struct ClientStatistics {
  var startedAt = ProcessInfo.processInfo.systemUptime
  var frames = 0
  var bytes = 0
  var commands = 0
  var decodeTime: TimeInterval = 0
  var renderTime: TimeInterval = 0
  var draws = 0
  var drawCalls = 0
  var instances = 0
  var gpuTime: TimeInterval = 0
  var gpuFrames = 0
  var requestTime: TimeInterval = 0
  var replies = 0

  mutating func reportIfNeeded() {
    let now = ProcessInfo.processInfo.systemUptime
    let elapsed = now - startedAt
    guard elapsed >= 1 else { return }
    let frameCount = max(1, frames)
    print(
      String(
        format:
          "client %.1f received fps | %.1f rendered fps | %.2f Mbit/s | %.0f commands/frame | decode %.2f ms | CPU encode %.2f ms | GPU %.2f ms | request %.2f ms | %.0f draws/frame | %.0f instances/frame",
        Double(frames) / elapsed, Double(draws) / elapsed,
        Double(bytes) * 8 / elapsed / 1_000_000,
        Double(commands) / Double(frameCount),
        decodeTime * 1_000 / Double(frameCount),
        renderTime * 1_000 / Double(max(1, draws)),
        gpuTime * 1_000 / Double(max(1, gpuFrames)),
        requestTime * 1_000 / Double(max(1, replies)),
        Double(drawCalls) / Double(max(1, draws)),
        Double(instances) / Double(max(1, draws))))
    fflush(stdout)
    self = Self()
    startedAt = now
  }
}
