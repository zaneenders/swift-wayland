@testable import RemoteServer
import Testing

@Suite("Latest-wins frame scheduling")
@MainActor
struct LatestFrameQueueTests {
  @Test func burstKeepsOnlyNewestWaitingFrame() {
    let queue = LatestFrameQueue<Int>()
    #expect(queue.submit(1) == 1)
    for frame in 2...1000 { #expect(queue.submit(frame) == nil) }
    #expect(queue.isBusy)
    #expect(queue.complete() == 1000)
    #expect(queue.isBusy)
    #expect(queue.complete() == nil)
    #expect(!queue.isBusy)
    #expect(queue.submit(1001) == 1001)
  }

  @Test func newFramesWaitThroughoutTransportWrite() {
    let queue = LatestFrameQueue<Int>()
    #expect(queue.submit(1) == 1)
    // Encoding finishing does not free the slot; completion represents write completion.
    #expect(queue.submit(2) == nil)
    #expect(queue.submit(3) == nil)
    #expect(queue.complete() == 3)
    #expect(queue.submit(4) == nil)
    #expect(queue.complete() == 4)
    #expect(queue.complete() == nil)
  }

  @Test func disconnectDiscardsPendingWithoutOverlappingInFlightWork() {
    let queue = LatestFrameQueue<Int>()
    #expect(queue.submit(1) == 1)
    #expect(queue.submit(2) == nil)
    queue.discardPending()
    #expect(queue.isBusy)
    // A new connection's first frame waits until old work completes.
    #expect(queue.submit(3) == nil)
    #expect(queue.complete() == 3)
    #expect(queue.complete() == nil)
  }

  @Test func allInputsApplyEvenWhenTheirSnapshotsAreReplaced() {
    let queue = LatestFrameQueue<[Int]>()
    var applied: [Int] = []
    for input in 1...100 {
      applied.append(input)
      let started = queue.submit(applied)
      #expect(started == (input == 1 ? [1] : nil))
    }
    #expect(queue.complete() == Array(1...100))
    #expect(queue.complete() == nil)
  }
}
