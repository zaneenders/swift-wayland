import ShapeTree

public struct PositionTestSimpleHorizontal: Block {
  public init() {}
  let scale: UInt = 5
  public var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.red)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.blue)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.green)
    }
  }
}

public struct PositionTestSimpleVertical: Block {
  public init() {}
  public var layer: some Block {
    Direction(.vertical) {
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.red)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.blue)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.green)
    }
  }
}

public struct EdgeCaseZeroSize: Block {
  public init() {}
  public var layer: some Block {
    Rect()
      .width(.fixed(0))
      .height(.fixed(0))
      .background(.red)
  }
}

public struct EdgeCaseVeryLarge: Block {
  public init() {}
  public var layer: some Block {
    Rect()
      .width(.fixed(UInt.max / 2))
      .height(.fixed(UInt.max / 2))
      .background(.red)
  }
}

public struct EdgeCaseDeepNesting: Block {
  // NOTE: This test is dumb what is it even testing
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Direction(.vertical) {
        Direction(.horizontal) {
          Direction(.vertical) {
            Rect()
              .width(.fixed(10))
              .height(.fixed(10))
              .background(.red)
          }
        }
      }
    }
  }
}

public struct ColorTestLayout: Block {
  public init() {}
  public var layer: some Block {
    Direction(.vertical) {
      Text("Red Background").background(.red)
      Text("Bright Yellow Background").background(.yellow)
      Text("Cyan Background").background(.cyan)
    }
  }
}

public struct PaddingTest: Block {
  public init(padding: UInt) {
    self.padding = padding
  }
  let padding: UInt
  public var layer: some Block {
    Text("Padding")
      .padding(padding)
  }
}

public struct Grow: Block {
  public init() {}
  public var layer: some Block {
    Rect().height(.grow).width(.grow)
      .background(.red)
  }
}

public struct IDK: Block {
  public init() {}
  public var layer: some Block {
    Text("IDk")
      .scale(3)
  }
}

public struct ScaledText: Block {
  let scale: UInt
  public init(scale: UInt) {
    self.scale = scale
  }
  public var layer: some Block {
    Text("Hello")
      .scale(scale)
  }
}

public struct RectTestMultiple: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.fixed(50))
        .height(.fixed(30))
        .background(.red)
      Rect()
        .width(.fixed(40))
        .height(.fixed(60))
        .background(.blue)
      Rect()
        .width(.fixed(30))
        .height(.fixed(40))
        .background(.green)
    }
  }
}

public struct RectTestNested: Block {
  public init() {}
  public var layer: some Block {
    Direction(.vertical) {
      Rect()
        .width(.fixed(100))
        .height(.fixed(20))
        .background(.red)
      Direction(.horizontal) {
        Rect()
          .width(.fixed(30))
          .height(.fixed(30))
          .background(.blue)
        Rect()
          .width(.fixed(30))
          .height(.fixed(30))
          .background(.green)
      }
      Rect()
        .width(.fixed(100))
        .height(.fixed(20))
        .background(.yellow)
    }
  }
}

public struct SpacingTestEmptyGroup: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {}
  }
}

public struct SpacingTestSingleElement: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Text("Single")
    }
  }
}

public struct SpacingTestWordRectMixed: Block {
  public init(scale: UInt) {
    self.scale = scale
  }
  let scale: UInt
  public var layer: some Block {
    Direction(.horizontal) {
      Text("Hello")
        .scale(scale)
      Rect()
        .width(.fixed(20 * scale))
        .height(.fixed(20 * scale))
        .background(.red)
      Text("World")
        .scale(scale)
    }
  }
}

public struct SpacingTestComplexNesting: Block {
  public init() {}
  public var layer: some Block {
    Direction(.vertical) {
      Text("Top")
      Direction(.horizontal) {
        Rect()
          .width(.fixed(15))
          .height(.fixed(15))
          .background(.red)
        Text("Middle")
        Rect()
          .width(.fixed(15))
          .height(.fixed(15))
          .background(.blue)
      }
      Direction(.horizontal) {
        Rect()
          .width(.fixed(10))
          .height(.fixed(10))
          .background(.green)
        Rect()
          .width(.fixed(10))
          .height(.fixed(10))
          .background(.yellow)
      }
      Text("Bottom")
    }
  }
}

public struct SpacingTestLargeGap: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.fixed(5))
        .height(.fixed(5))
        .background(.red)
      Rect()
        .width(.fixed(100))
        .height(.fixed(100))
        .background(.green)
      Rect()
        .width(.fixed(5))
        .height(.fixed(5))
        .background(.blue)
    }
  }
}

public struct QuadTestScaling: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.red)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.blue)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.green)
    }
  }
}

public struct RectTestBasic: Block {
  var scale: UInt = 1
  public init(scale: UInt) {
    self.scale = scale
  }
  public var layer: some Block {
    Rect()
      .width(.fixed(100 * scale))
      .height(.fixed(50 * scale))
      .background(.red)
  }
}

public struct RectTestScaled: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.red)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.blue)
      Rect()
        .width(.fixed(10))
        .height(.fixed(10))
        .background(.green)
    }
  }
}

public struct TextTestScaling: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Text("Small")
        .foreground(.red)
      Text("Medium")
        .foreground(.green)
      Text("Large")
        .foreground(.blue)
    }
  }
}

public struct GrowTestBasic: Block {
  public init() {}
  public var layer: some Block {
    Rect()
      .width(.grow)
      .height(.grow)
      .background(.red)
  }
}
