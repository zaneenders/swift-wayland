import Logging

struct MoveOut: Walker {
  var currentId: Hash
  let selected: Hash
  var found: Bool
  var new: Hash?

  init(_ renderer: borrowing LayoutMachine) {
    print("MoveOut: \(renderer.selected)")
    currentId = renderer.currentId
    selected = renderer.selected
    found = false
  }

  private mutating func moveOut(_ block: some Block) {
    if currentId == selected && found == false {
      print("Found: \(type(of: block))")
      found = true
    }
  }

  mutating func before(_ block: some Block) {
    moveOut(block)
  }

  mutating func after(_ block: some Block) {
    if found && new == nil {
      print("Selected: \(type(of: block))")
      new = currentId
    }
  }

  mutating func before(child block: some Block) {
    moveOut(block)
  }

  mutating func after(child block: some Block) {}
}

extension Block {
  public func moveOut(_ renderer: inout LayoutMachine) {
    var mover = MoveOut(renderer)
    self.walk(with: &mover)
    if let new = mover.new {
      renderer.selected = new
    } else {
      print("Did not move in")
    }
  }
}
