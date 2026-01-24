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
        // For vertical growth, use equalization algorithm in vertical containers
        if container.orientation == .vertical {
          // Calculate space for siblings using the tree structure for vertical growth
          if let siblings = tree[parentId] {
            let nonGrowingSiblings = siblings.filter { siblingId in
              guard let siblingAttrs = attributes[siblingId] else { return true }
              return siblingAttrs.height != .grow
            }
            // Calculate total space needed for non-growing siblings
            var fixedSpace: UInt = 0
            for siblingId in nonGrowingSiblings {
              if let siblingSize = sizes[siblingId] {
                fixedSpace += siblingSize.height
              }
            }

            // Get all growing siblings including current
            let growingSiblings = siblings.filter { siblingId in
              guard let siblingAttrs = attributes[siblingId] else { return false }
              return siblingAttrs.height == .grow
            }

            if !growingSiblings.isEmpty {
              // Calculate available space for growing elements
              let paddingSpace: UInt = 0  // TODO: Add padding calculation
              let childGapSpace: UInt = 0  // TODO: Add child gap calculation
              let totalFixedSize = fixedSpace + paddingSpace + childGapSpace
              let availableSpace = parent.height > totalFixedSize ? parent.height - totalFixedSize : 0

              // Apply equalization algorithm from transcript

              // First pass: collect all growing elements with their current sizes
              var growElements: [(id: Hash, size: UInt)] = []
              for growId in growingSiblings {
                if let growSize = sizes[growId] {
                  growElements.append((id: growId, size: growSize.height))
                }
              }

              // Sort by size to implement equalization algorithm
              growElements.sort { $0.size < $1.size }

              var remainingSpace = availableSpace
              var currentIndex = 0

              // Equalization: make all growing elements the same size
              while currentIndex < growElements.count - 1 && remainingSpace > 0 {
                let currentSize = growElements[currentIndex].size
                let nextSize = growElements[currentIndex + 1].size

                // Find how many elements have the current size
                var endIndex = currentIndex
                while endIndex < growElements.count && growElements[endIndex].size == currentSize {
                  endIndex += 1
                }

                let elementsToGrow = endIndex - currentIndex
                let sizeNeeded = (nextSize - currentSize) * UInt(elementsToGrow)

                if sizeNeeded <= remainingSpace {
                  // Grow these elements to match next size
                  for i in currentIndex..<endIndex {
                    growElements[i].size = nextSize
                  }
                  remainingSpace -= sizeNeeded
                } else {
                  // Can't reach next size, distribute remaining space equally
                  let additionalPerElement = remainingSpace / UInt(elementsToGrow)
                  for i in currentIndex..<endIndex {
                    growElements[i].size += additionalPerElement
                  }
                  remainingSpace = 0
                  break
                }

                currentIndex = endIndex
              }

              // If all elements are the same size and still have space, distribute equally
              if remainingSpace > 0 && currentIndex >= growElements.count - 1 {
                let additionalPerElement = remainingSpace / UInt(growElements.count)
                for i in 0..<growElements.count {
                  growElements[i].size += additionalPerElement
                }
              }

              // Update current container's size
              if let growIndex = growElements.firstIndex(where: { $0.id == currentId }) {
                container.height = growElements[growIndex].size
              }
            } else {
              // No growing siblings, this is the only one, use all available space
              container.height = parent.height
            }
          } else {
            // For horizontal containers, growing height just fills parent height
            container.height = parent.height
          }
        } else {
          // No siblings information, use full parent height
          container.height = parent.height
        }
        shouldUpdate = true
      }

      if case .grow = currentAttributes.width {

        // Calculate space for siblings using the tree structure
        if let siblings = tree[parentId] {
          let nonGrowingSiblings = siblings.filter { siblingId in
            guard let siblingAttrs = attributes[siblingId] else { return true }
            return siblingAttrs.width != .grow
          }
          // Calculate total space needed for non-growing siblings
          var fixedSpace: UInt = 0
          for siblingId in nonGrowingSiblings {
            if let siblingSize = sizes[siblingId] {
              fixedSpace += siblingSize.width
            }
          }

          // Get all growing siblings including current
          let growingSiblings = siblings.filter { siblingId in
            guard let siblingAttrs = attributes[siblingId] else { return false }
            return siblingAttrs.width == .grow
          }

          if !growingSiblings.isEmpty {
            // Calculate available space for growing elements
            let paddingSpace: UInt = 0  // TODO: Add padding calculation
            let childGapSpace: UInt = 0  // TODO: Add child gap calculation
            let totalFixedSize = fixedSpace + paddingSpace + childGapSpace
            let availableSpace = parent.width > totalFixedSize ? parent.width - totalFixedSize : 0

            // Apply equalization algorithm from transcript

            // First pass: collect all growing elements with their current sizes
            var growElements: [(id: Hash, size: UInt)] = []
            for growId in growingSiblings {
              if let growSize = sizes[growId] {
                growElements.append((id: growId, size: growSize.width))
              }
            }

            // Sort by size to implement equalization algorithm
            growElements.sort { $0.size < $1.size }

            var remainingSpace = availableSpace
            var currentIndex = 0

            // Equalization: make all growing elements the same size
            while currentIndex < growElements.count - 1 && remainingSpace > 0 {
              let currentSize = growElements[currentIndex].size
              let nextSize = growElements[currentIndex + 1].size

              // Find how many elements have the current size
              var endIndex = currentIndex
              while endIndex < growElements.count && growElements[endIndex].size == currentSize {
                endIndex += 1
              }

              let elementsToGrow = endIndex - currentIndex
              let sizeNeeded = (nextSize - currentSize) * UInt(elementsToGrow)

              if sizeNeeded <= remainingSpace {
                // Grow these elements to match next size
                for i in currentIndex..<endIndex {
                  growElements[i].size = nextSize
                }
                remainingSpace -= sizeNeeded
              } else {
                // Can't reach next size, distribute remaining space equally
                let additionalPerElement = remainingSpace / UInt(elementsToGrow)
                for i in currentIndex..<endIndex {
                  growElements[i].size += additionalPerElement
                }
                remainingSpace = 0
                break
              }

              currentIndex = endIndex
            }

            // If all elements are the same size and still have space, distribute equally
            if remainingSpace > 0 && currentIndex >= growElements.count - 1 {
              let additionalPerElement = remainingSpace / UInt(growElements.count)
              for i in 0..<growElements.count {
                growElements[i].size += additionalPerElement
              }
            }

            // Update current container's size
            if let growIndex = growElements.firstIndex(where: { $0.id == currentId }) {
              container.width = growElements[growIndex].size
            }
          } else {
            // No growing siblings, this is the only one, use all available space
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

    // BlockGroups (children of Direction containers) should also fill their parent
    if block is BlockGroup {
      container.width = parent.width
      container.height = parent.height
      sizes[currentId] = container
      return
    }

  }

  mutating func after(_ block: some Block) {}

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}

