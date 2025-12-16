import Wayland

struct Test1: Block {
    let o: Orientation
    let names = ["Tyler", "Mel"]
    var layer: some Block {
        Group(o) {
            Word(names[0]).scale(4)
            Word(names[1]).scale(4)
        }
    }
}
