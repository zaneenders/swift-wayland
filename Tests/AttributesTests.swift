import Testing

@testable import ShapeTree
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
    let (attributes, sizes, positions, grower) = TestUtils.walkBlock(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth)
    guard let paddingTestHash = TestUtils.TreeNavigator.findFirstTupleBlock(in: attributes),
      let node = sizes.sizes[paddingTestHash]
    else {
      Issue.record("Failed to find PaddingTest block")
      return
    }
    switch node {
    case .known(let container):
      #expect(container.height == 7 + (padding * 2))
      #expect(container.width == 41 + (padding * 2))
    case .unknown(_):
      Issue.record("unknown size")
    }
  }

  @Test
  func basicGrow() {
    let test = Grow()
    let (attributes, sizes, positions, grower) = TestUtils.walkBlock(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth)
    let root = attributes.tree[0]![0]
    let node = sizes.sizes[root]!
    print(node)
  }

  struct Grow: Block {
    var layer: some Block {
      Rect().height(.grow).width(.grow)
        .background(.red)
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
    let result = TestUtils.walkBlock(test, height: Wayland.windowHeight, width: Wayland.windowWidth)

    guard let tupleBlock = TestUtils.TreeNavigator.findFirstTupleBlock(in: result.attributes),
      let size = result.sizes.sizes[tupleBlock],
      case .known(let container) = size
    else {
      Issue.record("Failed to find tuple block or get size")
      return
    }

    let expectedWidth = (3 * Wayland.glyphW * 3) + (3 * 3) - 3  // 45 + 9 - 3 = 51
    let expectedHeight = Wayland.glyphH * 3  // 21

    #expect(container.width == expectedWidth, "Text width should be calculated correctly")
    #expect(container.height == expectedHeight, "Text height should be calculated correctly")
    #expect(container.orientation == .vertical, "Text orientation should be vertical")

    TestUtils.Assert.positiveSize(size)
  }

  @Test("Attributes apply function merges instead of replaces")
  func testAttributesApply() {
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

    #expect(mergedAttributes.width == .fixed(100), "Width should remain unchanged since overlay is .fit")
    #expect(mergedAttributes.height == .grow, "Height should be overridden with .grow")
    #expect(mergedAttributes.foreground == .red, "Foreground should remain unchanged since overlay is nil")
    #expect(mergedAttributes.background == .green, "Background should be overridden with green")
    #expect(mergedAttributes.borderColor == .blue, "BorderColor should remain unchanged since overlay is nil")
    #expect(mergedAttributes.borderWidth == 3, "BorderWidth should be overridden with 3")
    #expect(mergedAttributes.borderRadius == 5, "BorderRadius should remain unchanged since overlay is nil")
    #expect(mergedAttributes.scale == 2, "Scale should remain unchanged since overlay is nil")

    let expectedPadding = Padding(top: 20, right: 15, bottom: 10, left: 5)
    #expect(mergedAttributes.padding == expectedPadding, "Padding should be overridden with new values")
  }

  @Test("Attributes apply function with all nil/fit values preserves everything")
  func testAttributesApplyPreservesAll() {
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

    #expect(result.width == .fixed(200), "Width should remain unchanged")
    #expect(result.height == .grow, "Height should remain unchanged")
    #expect(result.foreground == .yellow, "Foreground should remain unchanged")
    #expect(result.background == .purple, "Background should remain unchanged")
    #expect(result.borderColor == .orange, "BorderColor should remain unchanged")
    #expect(result.borderWidth == 4, "BorderWidth should remain unchanged")
    #expect(result.borderRadius == 8, "BorderRadius should remain unchanged")
    #expect(result.scale == 3, "Scale should remain unchanged")
    #expect(result.padding == Padding(horizontal: 12, vertical: 6), "Padding should remain unchanged")
  }

  struct AttributeChainTest: Block {
    var layer: some Block {
      Text("Hello").background(.red).foreground(.blue)
    }
  }

  @Test
  func testAttributeAccumulation() {
    let test = AttributeChainTest()
    let result = TestUtils.walkBlock(test, height: Wayland.windowHeight, width: Wayland.windowWidth)
    let root = result.attributes.tree[0]![0]
    let text = result.attributes.tree[root]![0]
    #expect(result.attributes.attributes[text]!.background == .red)
    #expect(result.attributes.attributes[text]!.foreground == .blue)
  }

  @Test
  func testProposedAttributeAccumulation() {
    let baseAttributes = Attributes(background: .red)
    let additionalAttributes = Attributes(foreground: .blue)
    let mergedAttributes = baseAttributes.merge(additionalAttributes)

    #expect(mergedAttributes.background == .red, "Merged attributes should preserve background")
    #expect(mergedAttributes.foreground == .blue, "Merged attributes should include foreground")
  }
}
