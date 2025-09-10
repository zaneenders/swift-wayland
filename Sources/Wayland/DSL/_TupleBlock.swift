public struct _TupleBlock<each Component: Block>: Block, BlockGroup {
    let _children: (repeat each Component)

    init(_ child: repeat each Component) {
        self._children = (repeat each child)
    }
}

extension _TupleBlock {
    var children: [any Block] {
        var out: [any Block] = []
        for child in repeat (each _children) {
            out.append(child)
        }
        return out
    }
}

@MainActor
protocol BlockGroup {
    var children: [any Block] { get }
}
