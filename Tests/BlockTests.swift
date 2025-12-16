import Testing

@testable import SwiftWayland
@testable import Wayland

let baseHeight: UInt = 600
let baseWidth: UInt = 800

/*
These tests are kinda gross but they are better than nothing.
I will aim to improve them as this project takes more shape.
*/
@MainActor @Test
func horizontalTest1() {
  let tb = Test1(o: .horizontal)

  var count = 0
  let expectedLayers = [
    Consumed(startX: 0, startY: 0, orientation: .horizontal, width: 120, height: 28),
    Consumed(startX: 0, startY: 0, orientation: .horizontal, width: 192, height: 28),
  ]
  let expectedPos: [(x: UInt, y: UInt)] = [(0, 0), (120, 0)]
  var renderer = Renderer(
    (height: baseHeight, width: baseWidth),
    { q, r in
      Issue.record(#function)
    },
    { t, r in
      let expectedBackground = count == 0 ? Color.black : Color.pink
      let expectedForeground = count == 0 ? Color.yellow : Color.white
      #expect(t.background == expectedBackground)
      #expect(t.forground == expectedForeground)
      #expect(t.text == tb.names[count])
      #expect(r.layers[1] == expectedLayers[count])
      #expect(t.pos == expectedPos[count])
      count += 1
    })
  renderer.draw(block: tb)
}

@MainActor @Test
func verticalTest1() {
  let tb = Test1(o: .vertical)

  var count = 0
  let expectedPos: [(x: UInt, y: UInt)] = [(0, 0), (0, 32)]
  var renderer = Renderer(
    (height: baseHeight, width: baseWidth),
    { q, r in
      Issue.record(#function)
    },
    { t, r in
      let expectedBackground = count == 0 ? Color.black : Color.pink
      let expectedForeground = count == 0 ? Color.yellow : Color.white
      #expect(t.background == expectedBackground)
      #expect(t.forground == expectedForeground)
      #expect(t.text == tb.names[count])
      #expect(t.pos == expectedPos[count])
      count += 1
    })
  renderer.draw(block: tb)
}
