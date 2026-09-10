#if os(macOS)
import Chroma
import Metal
import MetalBackend

@MainActor
final class MetalReplay {
  let renderer: MetalDisplayListRenderer
  let queue: MTLCommandQueue
  let texture: MTLTexture

  init(viewport: Size) throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw BenchmarkError.failed("Metal device/queue unavailable")
    }
    self.queue = queue
    renderer = try MetalDisplayListRenderer(device: device, pixelFormat: .rgba8Unorm)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm, width: Int(viewport.width), height: Int(viewport.height), mipmapped: false)
    descriptor.usage = [.renderTarget]
    descriptor.storageMode = .private
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      throw BenchmarkError.failed("Offscreen texture unavailable")
    }
    self.texture = texture
  }

  /// Serial completion deliberately prevents overwriting any in-flight pooled buffer.
  /// CPU encoding excludes submission/wait; GPU timestamps exclude CPU preparation.
  func render(_ list: DrawList, viewport: Size) throws -> (cpu: Double, gpu: Double) {
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    guard let command = queue.makeCommandBuffer(),
      let encoder = command.makeRenderCommandEncoder(descriptor: pass)
    else {
      throw BenchmarkError.failed("Metal command creation failed")
    }
    let start = now()
    renderer.encode(list, viewport: viewport, rasterScale: Point(x: 1, y: 1), into: encoder)
    encoder.endEncoding()
    let cpu = now() - start
    command.commit()
    command.waitUntilCompleted()
    guard command.status == .completed else {
      throw BenchmarkError.failed("Metal execution failed: \(String(describing: command.error))")
    }
    renderer.finishFrame()
    return (cpu, max(0, command.gpuEndTime - command.gpuStartTime))
  }
}
#endif
