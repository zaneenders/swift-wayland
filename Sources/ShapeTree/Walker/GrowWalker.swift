@MainActor
struct GrowWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var sizes: [Hash: Container]
  let attributes: [Hash: Attributes]
  let tree: [Hash: [Hash]]

  mutating func before(_ block: some Block) {
    guard let parent = sizes[parentId] else {
      return
    }
    guard var container = sizes[currentId] else {
      return
    }

    // First, handle explicit grow attributes
    if let currentAttributes = attributes[currentId] {
      var shouldUpdate = false
      if case .grow = currentAttributes.height {
        container.height = parent.height
        shouldUpdate = true
      }
      if case .grow = currentAttributes.width {
        // Calculate space for siblings using the tree structure
        if let siblings = tree[parentId] {
          let nonGrowingSiblings = siblings.filter { siblingId in
            guard let siblingAttrs = attributes[siblingId] else { return true }
            return siblingId != currentId && siblingAttrs.width != .grow
          }
          
          if !nonGrowingSiblings.isEmpty {
            // Calculate total space needed for non-growing siblings
            var fixedSpace: UInt = 0
            for siblingId in nonGrowingSiblings {
              if let siblingSize = sizes[siblingId] {
                fixedSpace += siblingSize.width
              }
            }
            
            // Remaining space goes to growing elements
            let remainingSpace = parent.width > fixedSpace ? parent.width - fixedSpace : 0
            let growingElementCount = siblings.filter { siblingId in
              guard let siblingAttrs = attributes[siblingId] else { return false }
              return siblingAttrs.width == .grow
            }.count
            
            if growingElementCount > 0 {
              container.width = remainingSpace / UInt(growingElementCount)
            } else {
              container.width = remainingSpace
            }
          } else {
            // No non-growing siblings, use full parent width
            container.width = parent.width
          }
        } else {
          // No siblings information, use full parent width
          container.width = parent.width
        }
        shouldUpdate = true
      }
      if shouldUpdate {
        sizes[currentId] = container
        return
      }
    }

    // Direction containers should expand to fill their parent
    if block is DirectionGroup {
      // If this is a Direction container, it should fill the parent's size
      switch container.orientation {
      case .horizontal:
        container.width = parent.width
        container.height = parent.height
      case .vertical:
        container.height = parent.height
        container.width = parent.width
      }
      sizes[currentId] = container
      return
    }

    // For container elements (not leaf elements like Rect), expand to fill parent 
    // if they don't have explicit grow attributes
    let isContainerElement = block is DirectionGroup || block is BlockGroup
    if isContainerElement {
      if container.orientation == .horizontal && container.width < parent.width {
        container.width = parent.width
        container.height = parent.height
        sizes[currentId] = container
      } else if container.orientation == .vertical && container.height < parent.height {
        container.height = parent.height
        container.width = parent.width
        sizes[currentId] = container
      }
    }
  }

  mutating func after(_ block: some Block) {}

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
