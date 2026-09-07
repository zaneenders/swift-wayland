#if METAL_BACKEND

import AppKit
import Chroma
import MetalKit

@MainActor
public final class MetalRenderer: NSObject, MTKViewDelegate, NSWindowDelegate, Renderer {
  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let displayRenderer: MetalDisplayListRenderer
  private let mtkView: ChromaInputView

  public let name = "Metal"

  package let interaction = Interaction()

  public var content: (any Block)?
  public var onClose: (() -> Void)?
  private var keyBindings = KeyBindings() {
    didSet { mtkView.keyBindings = keyBindings }
  }
  private var minimumRefreshRate: Double = 0
  private var refreshTimer: Timer?

  package func setKeyBindings(_ bindings: KeyBindings) {
    keyBindings = bindings
  }

  package func setMinimumRefreshRate(_ refreshRate: Double) {
    minimumRefreshRate = refreshRate.isFinite ? max(0, refreshRate) : 0
    updateRefreshTimer()
  }

  public var contentView: NSView { mtkView }

  public init(frame: CGRect) throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw BackendError.unavailable(
        backend: "Metal",
        reason: "no compatible GPU was found"
      )
    }
    guard let queue = device.makeCommandQueue() else {
      throw BackendError.initializationFailed(
        backend: "Metal",
        stage: "command queue",
        reason: "the device could not create a command queue"
      )
    }
    self.device = device
    self.queue = queue

    let mtkView = ChromaInputView(frame: frame, device: device)
    mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
    mtkView.isPaused = true
    mtkView.enableSetNeedsDisplay = true
    self.mtkView = mtkView

    self.displayRenderer = try MetalDisplayListRenderer(
      device: device, pixelFormat: mtkView.colorPixelFormat)

    super.init()
    mtkView.delegate = self
    mtkView.interaction = interaction
    mtkView.keyBindings = keyBindings
    interaction.onRedrawRequested = { [weak mtkView] in
      mtkView?.needsDisplay = true
    }
  }

  public convenience init(size: Size) throws {
    try self.init(frame: CGRect(x: 0, y: 0, width: CGFloat(size.width), height: CGFloat(size.height)))
  }

  private func updateRefreshTimer() {
    refreshTimer?.invalidate()
    refreshTimer = nil
    guard minimumRefreshRate > 0 else { return }

    let timer = Timer(timeInterval: 1 / minimumRefreshRate, repeats: true) { [weak mtkView] _ in
      MainActor.assumeIsolated {
        mtkView?.needsDisplay = true
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    refreshTimer = timer
  }

  public func run(title: String) {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let window = NSWindow(
      contentRect: mtkView.frame,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.collectionBehavior.insert(.fullScreenPrimary)
    window.title = title
    window.contentView = mtkView
    window.delegate = self
    window.center()
    window.makeKeyAndOrderFront(nil)
    mtkView.needsDisplay = true
    window.makeFirstResponder(mtkView)

    app.activate(ignoringOtherApps: true)
    app.run()
  }

  public func windowWillClose(_ notification: Notification) {
    onClose?()
    NSApplication.shared.terminate(nil)
  }


  private var lastFrameTime: Double = 0
  private var smoothedFrameRate: Double = 0

  public func draw(in mtkView: MTKView) {
    guard
      let drawable = mtkView.currentDrawable,
      let rpd = mtkView.currentRenderPassDescriptor,
      let cmd = queue.makeCommandBuffer(),
      let enc = cmd.makeRenderCommandEncoder(descriptor: rpd)
    else {
      // The drawable may not be ready yet (e.g. before the view is attached to
      // a window). Retry next cycle so we don't stall on a blank view.
      mtkView.needsDisplay = true
      return
    }

    updateFrameRate()
    interaction.beginFrame(input: self.mtkView.frameInput())

    let viewport = Size(width: Float(mtkView.bounds.width), height: Float(mtkView.bounds.height))
    var drawList = DrawList()
    if let content {
      BlockEngine.draw(content, into: &drawList, in: Rect(origin: .zero, size: viewport), context: context)
    }
    interaction.endFrame()
    let redrawRequested = interaction.consumeRedrawRequest()
    displayRenderer.encode(
      drawList,
      viewport: viewport,
      rasterScale: Point(
        x: Float(drawable.texture.width) / max(1, viewport.width),
        y: Float(drawable.texture.height) / max(1, viewport.height)),
      into: enc)

    enc.endEncoding()
    cmd.present(drawable)
    cmd.commit()

    if redrawRequested {
      mtkView.needsDisplay = true
    }
    displayRenderer.finishFrame()
  }

  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    mtkView.needsDisplay = true
  }

  private func updateFrameRate() {
    let now = ProcessInfo.processInfo.systemUptime
    defer { lastFrameTime = now }
    guard lastFrameTime > 0 else { return }
    let delta = now - lastFrameTime
    guard delta > 0 else { return }
    let instant = 1 / delta
    smoothedFrameRate = smoothedFrameRate == 0 ? instant : smoothedFrameRate * 0.9 + instant * 0.1
    interaction.frameRate = smoothedFrameRate
  }



}

#elseif METAL_TRAIT
#error("The Metal backend requires macOS.")
#endif

#if METAL_BACKEND
import Metal

extension Rect {
  func asMtlScissor(scale: Point) -> MTLScissorRect {
    MTLScissorRect(
      x: Int((minX * scale.x).rounded(.down)),
      y: Int((minY * scale.y).rounded(.down)),
      width: Int((size.width * scale.x).rounded(.up)),
      height: Int((size.height * scale.y).rounded(.up))
    )
  }
}
#endif
