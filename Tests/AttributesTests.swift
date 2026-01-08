import Testing

@testable import Wayland

@Suite
@MainActor
struct AttributesTests {
  struct PaddingTest: Block {
    let padding: UInt
    var layer: some Block {
      Text("Padding")
        .padding(padding)
    }
  }

  @Test
  func testBasicPadding() {
    let padding: UInt = 15
    let test = PaddingTest(padding: padding)
    let (attributes, sizes, positions, grower) = TestUtils.walkBlock(test, height: height, width: width)
    let root = attributes.tree[0]![0]
    let node = sizes.sizes[root]!
    switch node {
    case .known(let container):
      #expect(container.height == 7 + (padding * 2))
      #expect(container.width == 41 + (padding * 2))
    case .unknown(_):
      Issue.record("unknown size")
    }
  }

  struct IDK: Block {
    var layer: some Block {
      Text("IDk")
        .scale(3)
    }
  }

  @Test("Text with scale and foreground color attributes")
  func idk() {
    let test = IDK()
    let result = TestUtils.walkBlock(test, height: height, width: width)

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
