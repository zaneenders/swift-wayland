import Logging

struct MoveIn: Walker {
  var currentId: Hash
  let selected: Hash
  var found: Bool
  var new: Hash?

  init(_ renderer: borrowing LayoutMachine) {
    print("MoveIn: \(renderer.selected)")
    currentId = renderer.currentId
    selected = renderer.selected
    found = false
  }

  mutating func before(_ block: some Block) {
    if currentId == selected && found == false {
      print("Found: \(type(of: block))")
      found = true
    }
  }

  mutating func after(_ block: some Block) {}

  mutating func before(child block: some Block) {
    if found && new == nil {
      print("Selected: \(type(of: block))")
      new = currentId
    }
  }

  mutating func after(child block: some Block) {}
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
