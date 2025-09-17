import Wayland

struct Test1: Block {
    let o: Orientation
    var layer: some Block {
        Group(o) {
            Word("Tyler").scale(4)
            Word("Mel").scale(4)
        }
    }
}
