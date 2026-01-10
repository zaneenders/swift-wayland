import Wayland

// Red background
struct FullGrowDemo: Block {
  var layer: some Block {
    Rect()
      .width(.grow)
      .height(.grow)
      .background(.red)
  }
}

// A small red rectangle with a blue rectangle extending to the edge of teh screen
struct MixedGrowDemo: Block {
  // BUG: Blue rectangle does not extend to the edge of the screen
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.fixed(200))
        .height(.fixed(100))
        .background(.red)
      Rect()
        .width(.grow)
        .height(.grow)
        .background(.blue)
    }
  }
}

// Should be 3 vertical bars of equal width
struct MultipleGrowDemo: Block {
  // BUG: doesn't display at all
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.grow)
        .height(.grow)
        .background(.red)
      Rect()
        .width(.grow)
        .height(.grow)
        .background(.green)
      Rect()
        .width(.grow)
        .height(.grow)
        .background(.blue)
    }
  }
}
