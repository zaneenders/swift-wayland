import Testing

@testable import Wayland

@Suite
@MainActor
struct AttributesTests {
  struct IDK: Block {
    var layer: some Block {
      Text("IDk")
        .scale(3)
    }
  }

  @Test("Text with scale and foreground color attributes")
  func idk() {
    let test = IDK()
    let result = TestUtils.walkBlock(test)

    // Find the Text block and check if scale is properly applied
    guard let tupleBlock = TestUtils.TreeNavigator.findTupleBlock(in: result.attributes),
      let size = result.sizes.sizes[tupleBlock],
      case .known(let container) = size
    else {
      Issue.record("Failed to find tuple block or get size")
      return
    }

    // Scale is now applied to text (scale=3)
    let expectedWidth = (3 * Wayland.glyphW * 3) + (3 * 3) - 3  // 45 + 9 - 3 = 51
    let expectedHeight = Wayland.glyphH * 3  // 21

    #expect(container.width == expectedWidth, "Text width should be calculated correctly")
    #expect(container.height == expectedHeight, "Text height should be calculated correctly")
    #expect(container.orientation == .vertical, "Text orientation should be vertical")

    TestUtils.Assert.positiveSize(size)
  }
}
