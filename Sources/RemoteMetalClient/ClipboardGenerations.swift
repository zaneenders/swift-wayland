/// Tracks clipboard versions observed by input gestures, without depending on AppKit.
struct ClipboardGenerations {
  private var pending: [UInt64: Int] = [:]

  mutating func record(sequence: UInt64, generation: Int) {
    pending[sequence] = generation
    // Bound metadata even when the application never uses clipboard commands.
    pending = pending.filter { sequence &- $0.key < 1024 }
  }

  mutating func consume(sequence: UInt64) -> Int? {
    pending.removeValue(forKey: sequence)
  }

  mutating func didWrite(sequence: UInt64, from oldGeneration: Int, to newGeneration: Int) {
    // Later gestures may already be queued behind this write on the daemon.
    // Advance only those that observed the same clipboard; never bless a stale
    // gesture whose version differs because another application changed it.
    for (id, generation) in pending where id > sequence && generation == oldGeneration {
      pending[id] = newGeneration
    }
  }

  mutating func removeAll() {
    pending.removeAll()
  }
}
