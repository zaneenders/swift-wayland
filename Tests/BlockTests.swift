import Testing

@testable import SwiftWayland
@testable import Wayland

let baseHeight: UInt = 600
let baseWidth: UInt = 800

@MainActor @Test 
func horizontalTest1() {
    let tb = Test1(o: .horizontal)

    var count = 0
    var renderer = Renderer(
        (height: baseHeight, width: baseWidth),
        { q, r in
            #expect(Bool(false))
        },
        { t, r in
            if count >= 1 {
                #expect(t.pos.x == 120)
                #expect(t.pos.y == 0)
                #expect(r.layers[0].height == 0)
                #expect(r.layers[0].width == 0)
                #expect(r.orientation == .horizontal)
            } else {
                #expect(count == 0)
            }
            count += 1
        })
    renderer.draw(block: tb)
}

@MainActor @Test 
func verticalTest1() {
    let tb = Test1(o: .vertical)

    var count = 0
    var renderer = Renderer(
        (height: baseHeight, width: baseWidth),
        { q, r in
            #expect(Bool(false))
        },
        { t, r in
            if count >= 1 {
                #expect(t.pos.x == 0)
                #expect(t.pos.y == 32)
                #expect(r.layers[0].height == 64)
                #expect(r.layers[0].width == 116)
                #expect(r.orientation == .vertical)
            } else {
                #expect(count == 0)
            }
            count += 1
        })
    renderer.draw(block: tb)
}
