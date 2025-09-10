import Testing

@testable import Wayland

@MainActor
@Test func idk() {
    let rect = TestBlock()
    parse(rect)
    #expect(true == true)
}

struct TestBlock: Block {
    var layer: some Block {
        Solid()
    }
}

@MainActor
func parse(_ block: some Block) {
    if let rect = block as? Solid {
        print(rect)
    } else {
        print("layer")
        parse(block.layer)
    }
}
