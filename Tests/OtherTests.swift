import Testing

@testable import SwiftWayland
@testable import Wayland

enum TestRenderer: Renderer {
  static func drawQuad(_ quad: Quad) {}
  static func drawText(_ text: Text) {}
}

@MainActor
@Test
func layout() {
  var sizer = SizeWalker()
  let test = LayoutTest()
  test.walk(with: &sizer)
  let testStruct = sizer.tree[0]![0]
  let tupleBlock = sizer.tree[testStruct]![0]
  #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 209, width: 348, orientation: .vertical)))
  var positioner = PositionWalker(sizes: sizer.sizes.convert())
  test.walk(with: &positioner)
  var renderWalker = RenderWalker(positions: positioner.positions, TestRenderer.self)
  test.walk(with: &renderWalker)
}

@Test func cloudFlare() async {
  let ips = await getIps()
  #expect(ips.count > 0)
  #expect(ips.allSatisfy { $0.contains(".") })
}

@Test func hashing() async {
  let chromaHash = hash("Chroma")
  #expect(chromaHash == 4_247_990_530_641_679_754)

  let chromaHash2 = hash("Chroma")
  #expect(chromaHash == chromaHash2)

  let rehash = hash(chromaHash)
  #expect(chromaHash != rehash)
}