// Computes the absolute positions to render elements.
struct PositionWalker: Walker {

  var currentId: Hash = 0
  var parentId: Hash = 0
  private(set) var positions: [Hash: (x: UInt, y: UInt)] = [:]
  private var sizes: [Hash: Container]
  private var currentX: UInt = 0
  private var currentY: UInt = 0
  private var layoutStack: [LayoutContext] = []

  init(sizes: [Hash: Container]) {
    self.sizes = sizes
  }

  mutating func before(_ block: some Block) {
    // Store the current position for this element
    positions[currentId] = (currentX, currentY)
    // For orientation blocks, push a new layout context
    if let group = block as? DirectionGroup {
      layoutStack.append(LayoutContext(x: currentX, y: currentY, orientation: group.orientation))
    }
  }

  mutating func after(_ block: some Block) {
    // For orientation blocks, pop the layout context and update parent position
    if block is DirectionGroup {
      if let context = layoutStack.popLast() {
        let size = sizes[currentId]!
        switch context.orientation {
        case .horizontal:
          currentX = context.x + size.width
          currentY = context.y
        case .vertical:
          currentX = context.x
          currentY = context.y + size.height
        }
      }
    } else {
      // For regular blocks, update current position based on their own orientation
      let size = sizes[currentId]!
      switch size.orientation {
      case .horizontal:
        currentX += size.width
      case .vertical:
        currentY += size.height
      }
    }
  }

  mutating func before(child block: some Block) {
    // For child blocks, reset to the current container's position
    if let context = layoutStack.last {
      currentX = context.x
      currentY = context.y
    }
  }

  mutating func after(child block: some Block) {
    // After processing a child, update the container's position for the next child
    if let childSize = sizes[currentId], layoutStack.count > 0 {
      let index = layoutStack.count - 1
      let context = layoutStack[index]
      switch context.orientation {
      case .horizontal:
        layoutStack[index] = LayoutContext(
          x: context.x + childSize.width, y: context.y, orientation: context.orientation)
      case .vertical:
        layoutStack[index] = LayoutContext(
          x: context.x, y: context.y + childSize.height, orientation: context.orientation)
      }
    }
  }
}

struct LayoutContext {
  let x: UInt
  let y: UInt
  let orientation: Orientation
}
