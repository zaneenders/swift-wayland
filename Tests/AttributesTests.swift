import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Suite struct AttributesTests {

  @Test
  func mergeAttributes() {
    let baseAttributes = Attributes(
      width: .fixed(100),
      height: .fit,
      foreground: .red,
      background: nil,
      borderColor: .blue,
      borderWidth: nil,
      borderRadius: 5,
      scale: 2,
      padding: Padding(all: 10)
    )

    let overlayAttributes = Attributes(
      width: .fit,
      height: .grow,
      foreground: nil,
      background: .green,
      borderColor: nil,
      borderWidth: 3,
      borderRadius: nil,
      scale: nil,
      padding: Padding(top: 20, right: 15, bottom: 10, left: 5)
    )

    let mergedAttributes = baseAttributes.merge(overlayAttributes)

    #expect(mergedAttributes.width == .fixed(100))
    #expect(mergedAttributes.height == .grow)
    #expect(mergedAttributes.foreground == .red)
    #expect(mergedAttributes.background == .green)
    #expect(mergedAttributes.borderColor == .blue)
    #expect(mergedAttributes.borderWidth == 3)
    #expect(mergedAttributes.borderRadius == 5)
    #expect(mergedAttributes.scale == 2)
    #expect(mergedAttributes.padding == Padding(top: 20, right: 15, bottom: 10, left: 5))
  }

  @Test
  func testAttributesMergePreservesAll() {
    let originalAttributes = Attributes(
      width: .fixed(200),
      height: .grow,
      foreground: .yellow,
      background: .purple,
      borderColor: .orange,
      borderWidth: 4,
      borderRadius: 8,
      scale: 3,
      padding: Padding(horizontal: 12, vertical: 6)
    )

    let emptyOverlay = Attributes()

    let result = originalAttributes.merge(emptyOverlay)

    #expect(result.width == .fixed(200))
    #expect(result.height == .grow)
    #expect(result.foreground == .yellow)
    #expect(result.background == .purple)
    #expect(result.borderColor == .orange)
    #expect(result.borderWidth == 4)
    #expect(result.borderRadius == 8)
    #expect(result.scale == 3)
    #expect(result.padding == Padding(horizontal: 12, vertical: 6))
  }
}
