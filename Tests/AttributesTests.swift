import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@Suite
@MainActor
struct AttributesTests {

  @Test
  func testBasicPadding() {
    let padding: UInt = 15
    let test = PaddingTest(padding: padding)
    let layout = calculateLayout(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)

    guard let paddingTestHash = layout.tree[0]?.first,
      let node = layout.sizes[paddingTestHash]
    else {
      Issue.record("Failed to find PaddingTest block")
      return
    }
    #expect(node.height == Wayland.windowHeight)
    #expect(node.width == Wayland.windowWidth)
  }

  @Test
  func basicGrow() {
    let test = Grow()
    let layout = calculateLayout(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)
    let root = layout.tree[0]![0]
    let node = layout.sizes[root]!
    print(node)
    // TODO: Test
  }

  @Test
  func testingGrow() {
    let test = ScaleTextBy3()
    let layout = calculateLayout(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)

    guard
      let tupleBlock = layout.tree[0]?.first,
      let container = layout.sizes[tupleBlock]
    else {
      Issue.record("Failed to find tuple block or get size")
      return
    }

    let expectedWidth = (3 * Wayland.glyphW * 3) + (3 * 3) - 3  // 45 + 9 - 3 = 51
    let expectedHeight = Wayland.glyphH * 3  // 21

    #expect(container.width == Wayland.windowWidth, "Text width should be calculated correctly")
    #expect(container.height == Wayland.windowHeight, "Text height should be calculated correctly")
    #expect(container.orientation == .vertical, "Text orientation should be vertical")
  }

  @Test
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

  @Test
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

  @Test
  func testAttributeAccumulation() {
    let test = AttributeChainTest()
    let layout = calculateLayout(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)
    let root = layout.tree[0]![0]
    let text = layout.tree[root]![0]
    #expect(layout.attributes[text]!.background == .red)
    #expect(layout.attributes[text]!.foreground == .blue)
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
