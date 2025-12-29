// Computes the absolute positions to render elements.
struct PositionWalker: Walker {

  var currentId: Hash = 0
  var parentId: Hash = 0
  private(set) var positions: [Hash: (x: UInt, y: UInt)] = [:]
  private var sizes: [Hash: Size]
  private var currentX: UInt = 0
  private var currentY: UInt = 0
  private var layoutStack: [(containerX: UInt, containerY: UInt, orientation: Orientation)] = []

  init(sizes: [Hash: Size]) {
    self.sizes = sizes
  }

  mutating func before(_ block: some Block) {
    // Store the current position for this element
    positions[currentId] = (currentX, currentY)
    // For orientation blocks, push a new layout context
    if let orientationBlock = block as? OrientationBlock {
      layoutStack.append((currentX, currentY, orientationBlock.orientation))
    }
  }

  mutating func after(_ block: some Block) {
    // For orientation blocks, pop the layout context and update parent position
    if block is OrientationBlock {
      if let (containerX, containerY, orientation) = layoutStack.popLast() {
        if let size = sizes[currentId] {
          switch size {
          case .known(let height, let width, _):
            switch orientation {
            case .horizontal:
              currentX = containerX + width
              currentY = containerY
            case .vertical:
              currentX = containerX
              currentY = containerY + height
            }
          case .unknown:
            break
          }
        }
      }
    } else {
      // For regular blocks, update current position based on their own orientation
      if let size = sizes[currentId] {
        switch size {
        case .known(let height, let width, let orientation):
          switch orientation {
          case .horizontal:
            currentX += width
          case .vertical:
            currentY += height
          }
        case .unknown:
          break
        }
      }
    }
  }

  mutating func before(child block: some Block) {
    // For child blocks, reset to the current container's position
    if let (containerX, containerY, _) = layoutStack.last {
      currentX = containerX
      currentY = containerY
    }
  }

  mutating func after(child block: some Block) {
    // After processing a child, update the container's position for the next child
    if let childSize = sizes[currentId], layoutStack.count > 0 {
      let index = layoutStack.count - 1
      let (containerX, containerY, orientation) = layoutStack[index]

      switch childSize {
      case .known(let height, let width, _):
        switch orientation {
        case .horizontal:
          layoutStack[index] = (containerX + width, containerY, orientation)
        case .vertical:
          layoutStack[index] = (containerX, containerY + height, orientation)
        }
      case .unknown:
        break
      }
    }
  }
}
