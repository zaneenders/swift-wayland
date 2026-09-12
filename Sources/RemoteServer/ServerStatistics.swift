import Foundation
import Logging

struct ServerStatistics {
  private var logger = Logger(label: "chroma.remote.server")
  var startedAt = ProcessInfo.processInfo.systemUptime
  var frames = 0
  var bytes = 0
  var imageBytes = 0
  var commands = 0
  var drawTime: TimeInterval = 0
  var encodeTime: TimeInterval = 0

  mutating func record(
    byteCount: Int, commandCount: Int, drawDuration: TimeInterval, encodeDuration: TimeInterval
  ) {
    frames += 1
    bytes += byteCount
    commands += commandCount
    drawTime += drawDuration
    encodeTime += encodeDuration
    let now = ProcessInfo.processInfo.systemUptime
    let elapsed = now - startedAt
    guard elapsed >= 1 else { return }
    let frameCount = max(1, frames)
    let megabitsPerSecond = Double(bytes) * 8 / elapsed / 1_000_000
    logger.info(
      "Remote rendering statistics",
      metadata: [
        "fps": "\(String(format: "%.1f", Double(frames) / elapsed))",
        "megabits_per_second": "\(String(format: "%.2f", megabitsPerSecond))",
        "commands_per_frame": "\(String(format: "%.0f", Double(commands) / Double(frameCount)))",
        "image_mbit_s": "\(String(format: "%.2f", Double(imageBytes) * 8 / elapsed / 1_000_000))",
        "command_mbit_s":
          "\(String(format: "%.2f", Double(bytes - imageBytes) * 8 / elapsed / 1_000_000))",
        "draw_ms": "\(String(format: "%.2f", drawTime * 1_000 / Double(frameCount)))",
        "encode_ms": "\(String(format: "%.2f", encodeTime * 1_000 / Double(frameCount)))",
      ])
    self = Self()
    startedAt = now
  }
}
