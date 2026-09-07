import Chroma
import Foundation
import RemoteServer

@main
struct RemoteDemoDaemon {
  @MainActor
  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") || arguments.contains("-h") {
      print("usage: RemoteDemoDaemon [bind-host] [port] [fps] [items]")
      print("example: RemoteDemoDaemon 0.0.0.0 9328 30 2000")
      return
    }
    let host = arguments.first ?? "127.0.0.1"
    let port = arguments.dropFirst().first.flatMap(Int.init) ?? 9328
    let fps = arguments.dropFirst(2).first.flatMap(Double.init) ?? 30
    let itemCount = arguments.dropFirst(3).first.flatMap(Int.init) ?? 2_000

    let server = RemoteServer(
      content: PerformanceDemo(itemCount: max(1, itemCount)),
      size: Size(width: 1100, height: 720))
    server.setRefreshRate(fps)
    try server.start(host: host, port: port)
    print("Performance scene: \(itemCount) animated shapes at \(fps) requested fps")
    server.run()
  }
}

private struct PerformanceDemo: PrimitiveBlock {
  let itemCount: Int

  var expandsHorizontally: Bool { true }
  var expandsVertically: Bool { true }

  func sizeThatFits(_ proposal: Size, context: RenderContext) -> Size { proposal }

  func draw(into drawList: inout DrawList, in rect: Rect, context: RenderContext) {
    let background = Color(r: 0.025, g: 0.035, b: 0.065, a: 1)
    drawList.fillRect(rect, color: background)

    let headerHeight: Float = 72
    drawList.fillRect(
      Rect(x: rect.minX, y: rect.minY, width: rect.size.width, height: headerHeight),
      color: Color(r: 0.06, g: 0.08, b: 0.14, a: 1))
    drawList.text(
      "CHROMA REMOTE PERFORMANCE", at: Point(x: 24, y: 16),
      color: .yellow, scale: 0.9, face: .display)
    drawList.text(
      "\(itemCount) moving shapes — server builds and serializes every complete frame",
      at: Point(x: 24, y: 46), color: Color(r: 0.7, g: 0.76, b: 0.88, a: 1), scale: 0.55)

    let area = Rect(
      x: rect.minX + 16, y: rect.minY + headerHeight + 16,
      width: max(1, rect.size.width - 32), height: max(1, rect.size.height - headerHeight - 32))
    drawList.pushClip(area)

    let columns = max(1, Int(sqrt(Double(itemCount) * Double(area.size.width / area.size.height))))
    let rows = max(1, (itemCount + columns - 1) / columns)
    let cellWidth = area.size.width / Float(columns)
    let cellHeight = area.size.height / Float(rows)
    let elapsed = Float(Date().timeIntervalSinceReferenceDate)

    for index in 0..<itemCount {
      let column = index % columns
      let row = index / columns
      let phase = elapsed * 1.8 + Float(index) * 0.071
      let waveX = sin(phase) * cellWidth * 0.22
      let waveY = cos(phase * 0.73) * cellHeight * 0.22
      let width = max(2, cellWidth * 0.58)
      let height = max(2, cellHeight * 0.58)
      let shape = Rect(
        x: area.minX + Float(column) * cellWidth + (cellWidth - width) / 2 + waveX,
        y: area.minY + Float(row) * cellHeight + (cellHeight - height) / 2 + waveY,
        width: width, height: height)
      let hue = Float(index % 97) / 97
      let color = Color(
        r: 0.25 + 0.7 * abs(sin(hue * 6.283 + elapsed * 0.2)),
        g: 0.25 + 0.7 * abs(sin(hue * 6.283 + 2.1)),
        b: 0.25 + 0.7 * abs(sin(hue * 6.283 + 4.2)),
        a: 0.9)
      if index.isMultiple(of: 3) {
        drawList.fillRoundedRect(shape, radius: min(width, height) * 0.3, color: color)
      } else if index.isMultiple(of: 3) == false && index.isMultiple(of: 2) {
        drawList.strokeRect(shape, width: 1, color: color)
      } else {
        drawList.fillRect(shape, color: color)
      }
    }
    drawList.popClip()
  }
}
