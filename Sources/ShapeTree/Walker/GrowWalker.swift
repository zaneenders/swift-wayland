@MainActor
struct GrowWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var sizes: [Hash: Container]
  let attributes: [Hash: Attributes]
  let tree: [Hash: [Hash]]

  init(sizes: [Hash: Container], attributes: [Hash: Attributes], tree: [Hash: [Hash]]) {
    self.sizes = sizes
    self.attributes = attributes
    self.tree = tree
  }

  // Check whether any descendant of `nodeId` has a .grow width or height.
  private func hasGrowDescendant(_ nodeId: Hash, width: Bool, height: Bool) -> Bool {
    guard let children = tree[nodeId] else { return false }
    for childId in children {
      if width, attributes[childId]?.width == .grow { return true }
      if height, attributes[childId]?.height == .grow { return true }
      if hasGrowDescendant(childId, width: width, height: height) { return true }
    }
    return false
  }

  mutating func before(_ block: some Block) {
    guard let children = tree[currentId], !children.isEmpty else { return }
    guard var container = sizes[currentId] else { return }
    guard let parent = sizes[parentId] else { return }

    let needW = hasGrowDescendant(currentId, width: true, height: false)
    let needH = hasGrowDescendant(currentId, width: false, height: true)

    if needW && container.width < parent.width {
      container.width = parent.width
    }
    if needH && container.height < parent.height {
      container.height = parent.height
    }

    if (needW && container.width == parent.width) || (needH && container.height == parent.height) {
      sizes[currentId] = container
    }
  }

  mutating func after(_ block: some Block) {
    guard let children = tree[currentId], !children.isEmpty else { return }
    guard let container = sizes[currentId] else { return }

    // Collect grow children and compute fixed-space consumption.
    var hGrowers: [Hash] = []  // .grow width
    var vGrowers: [Hash] = []  // .grow height
    var fixedWidth: UInt = 0
    var fixedHeight: UInt = 0

    for childId in children {
      guard let childSize = sizes[childId] else { continue }
      let attrs = attributes[childId]

      if attrs?.width == .grow {
        hGrowers.append(childId)
      } else {
        fixedWidth += childSize.width
      }

      if attrs?.height == .grow {
        vGrowers.append(childId)
      } else {
        fixedHeight += childSize.height
      }
    }

    // Primary-axis distribution: .grow children share remaining space along
    // the container's orientation axis. Cross-axis: .grow children fill the
    // full container extent (like flexbox align-items: stretch).
    if container.orientation == .horizontal {
      // Primary: distribute remaining width to .grow width children.
      if !hGrowers.isEmpty {
        let remaining = container.width > fixedWidth ? container.width - fixedWidth : 0
        let share = remaining / UInt(hGrowers.count)
        for childId in hGrowers {
          if var childSize = sizes[childId] {
            childSize.width = share
            sizes[childId] = childSize
          }
        }
      }
      // Cross-axis: .grow height children fill container height.
      for childId in children {
        if var childSize = sizes[childId], attributes[childId]?.height == .grow {
          childSize.height = container.height
          sizes[childId] = childSize
        }
      }
    } else {
      // Primary: distribute remaining height to .grow height children.
      if !vGrowers.isEmpty {
        let remaining = container.height > fixedHeight ? container.height - fixedHeight : 0
        let share = remaining / UInt(vGrowers.count)
        for childId in vGrowers {
          if var childSize = sizes[childId] {
            childSize.height = share
            sizes[childId] = childSize
          }
        }
      }
      // Cross-axis: .grow width children fill container width.
      for childId in children {
        if var childSize = sizes[childId], attributes[childId]?.width == .grow {
          childSize.width = container.width
          sizes[childId] = childSize
        }
      }
    }
  }

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
