import Logging

struct MoveIn: Walker {
  var currentId: Hash
  let selected: Hash
  var found: Bool
  var new: Hash?

  init(_ renderer: borrowing LayoutMachine) {
    currentId = 0
    selected = renderer.selected
    found = false
  }

  mutating func before(_ block: some Block) {
    if found {
      new = currentId
    }
    if currentId == selected {
      found = true
    }
  }

  mutating func after(_ block: some Block) {}
}

extension Block {
  public func moveIn(_ renderer: inout LayoutMachine) {
    var moveIn = MoveIn(renderer)
    self.walk(with: &moveIn)
    if let new = moveIn.new {
      renderer.selected = new
    } else {
      print("Did not move in")
    }
  }
}
