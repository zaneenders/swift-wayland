import Chroma
import Foundation
import RemoteServer

@main
struct RemoteDemoDaemon {
  @MainActor
  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") || arguments.contains("-h") {
      print("usage: RemoteDemoDaemon [bind-host] [port] [items]")
      print("example: RemoteDemoDaemon 0.0.0.0 9328 2000")
      return
    }
    let host = arguments.first ?? "127.0.0.1"
    let port = arguments.dropFirst().first.flatMap(Int.init) ?? 9328
    let itemCount = arguments.dropFirst(2).first.flatMap(Int.init) ?? 2_000
    let state = PerformanceDemoState(itemCount: itemCount)

    let server = RemoteServer(
      content: PerformanceDemo(state: state).chromaTheme(.dark),
      size: Size(width: 1100, height: 720))
    try server.start(host: host, port: port)
    print("Interactive performance scene: \(state.itemCount) animated shapes")
    print("Click the controls in the remote window or use the arrow keys and Enter")
    server.run()
  }
}

@MainActor
private final class PerformanceDemoState {
  enum Palette: String, CaseIterable {
    case neon = "NEON"
    case sunset = "SUNSET"
    case ocean = "OCEAN"
  }

  enum Shape: String, CaseIterable {
    case mixed = "MIXED"
    case rounded = "ROUNDED"
    case outline = "OUTLINE"
  }

  var itemCount: Int
  var speed: Float = 1
  var palette: Palette = .neon
  var shape: Shape = .mixed
  var isPaused = false
  var timeOffset: TimeInterval = 0
  var pauseStartedAt: TimeInterval?
  var burst = 0
  let uuidScrollController = ScrollViewController()
  var identifiers = (1...10_000).map { _ in UUID().uuidString }
  var lastAction = "Ready — choose a control"

  init(itemCount: Int) {
    self.itemCount = min(20_000, max(100, itemCount))
  }

  func regenerateIdentifiers() {
    identifiers = (1...10_000).map { _ in UUID().uuidString }
    lastAction = "Generated 10,000 new UUIDs"
  }

  func adjustItems(by amount: Int) {
    itemCount = min(20_000, max(100, itemCount + amount))
    lastAction = "Density changed to \(itemCount) shapes"
  }

  func cycleSpeed() {
    speed = speed >= 2 ? 0.5 : speed + 0.5
    lastAction = "Animation speed is now \(speedLabel)"
  }

  func cyclePalette() {
    let values = Palette.allCases
    palette = values[(values.firstIndex(of: palette)! + 1) % values.count]
    lastAction = "Switched to the \(palette.rawValue.lowercased()) palette"
  }

  func cycleShape() {
    let values = Shape.allCases
    shape = values[(values.firstIndex(of: shape)! + 1) % values.count]
    lastAction = "Shape style is now \(shape.rawValue.lowercased())"
  }

  func togglePaused() {
    let now = Date().timeIntervalSinceReferenceDate
    if let pauseStartedAt {
      timeOffset += now - pauseStartedAt
      self.pauseStartedAt = nil
      isPaused = false
      lastAction = "Animation resumed"
    } else {
      pauseStartedAt = now
      isPaused = true
      lastAction = "Animation paused — controls still work"
    }
  }

  func triggerBurst() {
    burst &+= 1
    lastAction = "Burst #\(burst) randomized every phase"
  }

  var speedLabel: String { String(format: "%.1f×", speed) }

  func elapsedTime() -> Float {
    let now = pauseStartedAt ?? Date().timeIntervalSinceReferenceDate
    return Float(now - timeOffset) * speed
  }
}

private let remoteSmallText: Float = 0.52
private let remoteTitleText: Float = 0.82

private struct PerformanceDemo: Block {
  let state: PerformanceDemoState

  var body: some Block {
    ThemeReader { theme in
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          VStack(spacing: 3) {
            Text("CHROMA / REMOTE LAB")
              .fontScale(remoteTitleText)
              .foregroundColor(theme.accent)
            Text("The controls and state live on the daemon; only drawing commands cross the wire.")
              .fontScale(remoteSmallText)
              .foregroundColor(theme.secondaryForeground)
          }
          Spacer()
          Text(state.isPaused ? "● PAUSED" : "● LIVE")
            .fontScale(remoteSmallText)
            .foregroundColor(state.isPaused ? .yellow : Color(r: 0.25, g: 0.95, b: 0.55, a: 1))
        }
        .padding(16)
        .background(theme.elevatedSurface)
        .border(theme.border)

        HStack(spacing: 8) {
          Button(state.isPaused ? "Resume" : "Pause", id: WidgetID("remote.pause"), fontScale: remoteSmallText) {
            state.togglePaused()
          }
          Button("− 500", id: WidgetID("remote.fewer"), fontScale: remoteSmallText) {
            state.adjustItems(by: -500)
          }
          Button("+ 500", id: WidgetID("remote.more"), fontScale: remoteSmallText) {
            state.adjustItems(by: 500)
          }
          Button("Speed \(state.speedLabel)", id: WidgetID("remote.speed"), fontScale: remoteSmallText) {
            state.cycleSpeed()
          }
          Button(state.palette.rawValue, id: WidgetID("remote.palette"), fontScale: remoteSmallText) {
            state.cyclePalette()
          }
          Button(state.shape.rawValue, id: WidgetID("remote.shape"), fontScale: remoteSmallText) {
            state.cycleShape()
          }
          Button("Burst!", id: WidgetID("remote.burst"), fontScale: remoteSmallText) {
            state.triggerBurst()
          }
          Spacer()
        }
        .padding(10)
        .background(theme.surface)
        .border(theme.border)

        HStack(spacing: 10) {
          ShapeCanvas(state: state)
            .sizing(x: .grow, y: .grow)
            .clipped()

          UUIDList(state: state)
            .sizing(x: .fixed(330), y: .grow)
        }
        .padding(10)

        HStack(spacing: 12) {
          Text(state.lastAction)
            .fontScale(remoteSmallText)
            .foregroundColor(theme.foreground)
          Spacer()
          Text("\(state.itemCount) shapes  •  \(state.palette.rawValue)  •  \(state.shape.rawValue)")
            .fontScale(remoteSmallText)
            .foregroundColor(theme.accent)
        }
        .padding(10)
        .background(theme.elevatedSurface)
        .border(theme.border)
      }
      .background(theme.background)
    }
  }
}

private struct UUIDList: Block {
  let state: PerformanceDemoState

  var body: some Block {
    ThemeReader { theme in
      VStack(spacing: 8) {
        Text("\(state.identifiers.count) UUIDs / SCROLL TEST")
          .fontScale(remoteSmallText)
          .foregroundColor(theme.accent)
        Text("Scroll here with the wheel or trackpad.")
          .fontScale(remoteSmallText)
          .foregroundColor(theme.secondaryForeground)
        HStack(spacing: 6) {
          Button("Generate", id: WidgetID("remote.uuid.generate"), fontScale: remoteSmallText) {
            state.regenerateIdentifiers()
          }
          Button("Top", id: WidgetID("remote.uuid.top"), fontScale: remoteSmallText) {
            state.uuidScrollController.scrollToTop()
          }
          Button("Bottom", id: WidgetID("remote.uuid.bottom"), fontScale: remoteSmallText) {
            state.uuidScrollController.scrollToBottom()
          }
        }
        ScrollView(id: WidgetID("remote.uuid.scroll"), controller: state.uuidScrollController) {
          VStack(spacing: 5) {
            for index in state.identifiers.indices {
              VStack(spacing: 3) {
                Text("UUID \(index + 1)")
                  .fontScale(remoteSmallText)
                  .foregroundColor(theme.secondaryForeground)
                Text(state.identifiers[index])
                  .fontScale(remoteSmallText)
                  .foregroundColor(theme.foreground)
              }
              .padding(8)
              .sizing(x: .grow)
              .roundedBackground(theme.elevatedSurface, radius: 4)
            }
          }
          .padding(8)
        }
        .sizing(x: .grow, y: .grow)
        .border(theme.border)
      }
      .padding(10)
      .background(theme.surface)
      .border(theme.border)
    }
  }
}

private struct ShapeCanvas: PrimitiveBlock {
  let state: PerformanceDemoState

  var expandsHorizontally: Bool { true }
  var expandsVertically: Bool { true }

  func sizeThatFits(_ proposal: Size, context: RenderContext) -> Size { proposal }

  func draw(into drawList: inout DrawList, in rect: Rect, context: RenderContext) {
    drawList.fillRect(rect, color: Color(r: 0.025, g: 0.035, b: 0.065, a: 1))

    let area = Rect(
      x: rect.minX + 16, y: rect.minY + 16,
      width: max(1, rect.size.width - 32), height: max(1, rect.size.height - 32))
    drawList.pushClip(area)

    let count = state.itemCount
    let columns = max(1, Int(sqrt(Double(count) * Double(area.size.width / area.size.height))))
    let rows = max(1, (count + columns - 1) / columns)
    let cellWidth = area.size.width / Float(columns)
    let cellHeight = area.size.height / Float(rows)
    let elapsed = state.elapsedTime()
    let burstPhase = Float(state.burst) * 1.731

    for index in 0..<count {
      let column = index % columns
      let row = index / columns
      let phase = elapsed * 1.8 + Float(index) * 0.071 + burstPhase
      let waveX = sin(phase) * cellWidth * 0.22
      let waveY = cos(phase * 0.73 + burstPhase) * cellHeight * 0.22
      let pulse = 0.48 + 0.12 * abs(sin(phase * 0.41))
      let width = max(2, cellWidth * pulse)
      let height = max(2, cellHeight * pulse)
      let shapeRect = Rect(
        x: area.minX + Float(column) * cellWidth + (cellWidth - width) / 2 + waveX,
        y: area.minY + Float(row) * cellHeight + (cellHeight - height) / 2 + waveY,
        width: width, height: height)
      let hue = Float(index % 97) / 97
      let color = color(for: hue, elapsed: elapsed, palette: state.palette)

      switch state.shape {
      case .rounded:
        drawList.fillRoundedRect(shapeRect, radius: min(width, height) * 0.38, color: color)
      case .outline:
        drawList.strokeRect(shapeRect, width: 1, color: color)
      case .mixed:
        if index.isMultiple(of: 3) {
          drawList.fillRoundedRect(shapeRect, radius: min(width, height) * 0.3, color: color)
        } else if index.isMultiple(of: 2) {
          drawList.strokeRect(shapeRect, width: 1, color: color)
        } else {
          drawList.fillRect(shapeRect, color: color)
        }
      }
    }
    drawList.popClip()
  }

  private func color(for hue: Float, elapsed: Float, palette: PerformanceDemoState.Palette) -> Color {
    let phase = hue * 6.283 + elapsed * 0.2
    switch palette {
    case .neon:
      return Color(
        r: 0.25 + 0.7 * abs(sin(phase)),
        g: 0.25 + 0.7 * abs(sin(phase + 2.1)),
        b: 0.25 + 0.7 * abs(sin(phase + 4.2)), a: 0.9)
    case .sunset:
      return Color(
        r: 0.72 + 0.27 * abs(sin(phase)),
        g: 0.14 + 0.42 * abs(sin(phase + 1.7)),
        b: 0.22 + 0.4 * abs(sin(phase + 3.5)), a: 0.92)
    case .ocean:
      return Color(
        r: 0.08 + 0.28 * abs(sin(phase + 4.1)),
        g: 0.38 + 0.52 * abs(sin(phase + 2.0)),
        b: 0.62 + 0.36 * abs(sin(phase)), a: 0.92)
    }
  }
}
