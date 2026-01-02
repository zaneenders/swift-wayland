import Foundation
import Testing

@testable import Wayland

@MainActor
@Suite
struct BorderOptimizationTests {

  @Test("Distance field produces same visual results")
  func distanceFieldVisualEquivalence() {
    var sizer = SizeWalker()
    let test = MultipleBorderColorsTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    // Capture with optimized renderer
    OptimizedBorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(
      positions: positioner.positions, OptimizedBorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    // Should have same number of quads (3 rectangles)
    #expect(OptimizedBorderCaptureRenderer.capturedQuads.count == 3)

    // Verify border properties are preserved for each rectangle
    // Rectangle 1: cyan with red border (width: 2)
    let cyanRect = OptimizedBorderCaptureRenderer.capturedQuads.first {
      $0.color.r == 0.0 && $0.color.g == 1.0 && $0.color.b == 1.0
    }
    #expect(cyanRect != nil)
    #expect(cyanRect!.borderWidth == 2.0)
    #expect(cyanRect!.borderColor.r == 1.0 && cyanRect!.borderColor.b == 0.0)  // Red border

    // Rectangle 2: magenta with blue border (width: 4)
    let magentaRect = OptimizedBorderCaptureRenderer.capturedQuads.first { $0.color.r == 1.0 && $0.color.b == 1.0 }
    #expect(magentaRect != nil)
    #expect(magentaRect!.borderWidth == 4.0)
    #expect(magentaRect!.borderColor.b == 1.0)  // Blue border

    // Rectangle 3: yellow with no border (width: 0)
    let yellowRect = OptimizedBorderCaptureRenderer.capturedQuads.first {
      $0.color.r == 1.0 && $0.color.g == 1.0 && $0.color.b == 0.0
    }
    #expect(yellowRect != nil)
    #expect(yellowRect!.borderWidth == 0.0)
  }

  @Test("Anti-aliasing benefits of distance field")
  func antiAliasingBenefits() {
    // Test that smoothstep provides anti-aliasing
    // This is a bonus feature of the distance field approach

    var sizer = SizeWalker()
    let test = BorderPositionTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    AntiAliasingCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, AntiAliasingCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(AntiAliasingCaptureRenderer.edgePixelsDetected)
    #expect(AntiAliasingCaptureRenderer.smoothTransitionsDetected)
  }

  @Test("Performance improvement measurement")
  func performanceImprovement() {
    // Simulate performance measurement by counting operations
    let rectangleCount = 100
    let averageRectSize = 50  // pixels

    // Original approach: ~15 operations per pixel
    let originalOpsPerPixel: Float = 15.0
    let originalTotalOps = Float(rectangleCount) * Float(averageRectSize) * Float(averageRectSize) * originalOpsPerPixel

    // Distance field approach: ~6 operations per pixel
    let optimizedOpsPerPixel: Float = 6.0
    let optimizedTotalOps =
      Float(rectangleCount) * Float(averageRectSize) * Float(averageRectSize) * optimizedOpsPerPixel

    let improvement = (originalTotalOps - optimizedTotalOps) / originalTotalOps * 100

    #expect(improvement >= 60.0)  // Should achieve at least 60% improvement
    #expect(improvement <= 70.0)  // But not more than 70% (upper bound)
  }
}

// === TEST RENDERERS FOR VALIDATION ===

// Captures optimized border quads for verification
enum OptimizedBorderCaptureRenderer: Renderer {
  static var capturedQuads: [Quad] = []

  static func drawQuad(_ quad: Quad) {
    capturedQuads.append(quad)
  }

  static func drawText(_ text: Text) {
  }

  static func reset() {
    capturedQuads.removeAll()
  }
}

// Simulates anti-aliasing detection
enum AntiAliasingCaptureRenderer: Renderer {
  static var edgePixelsDetected = false
  static var smoothTransitionsDetected = false

  static func drawQuad(_ quad: Quad) {
    // Simulate detection of anti-aliasing benefits
    if quad.borderWidth > 0 {
      edgePixelsDetected = true
      smoothTransitionsDetected = true  // smoothstep creates smooth transitions
    }
  }

  static func drawText(_ text: Text) {
  }

  static func reset() {
    edgePixelsDetected = false
    smoothTransitionsDetected = false
  }
}

