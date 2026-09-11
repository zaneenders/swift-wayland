import Chroma
import RemoteProtocol
import Testing

@testable import RemoteMetalClient

struct RemoteFrameStateTests {
  @Test func dropsBadFrameAndReleasesCredit() {
    var state = RemoteFrameState()
    let viewport = Size(width: 800, height: 600)
    let good = RemoteMessage.frame(id: 1, inputSequence: 0, viewport: viewport, commands: [])
    let firstAccepted = state.receive(good)
    #expect(firstAccepted)
    state.requestOutstanding = true
    let badAccepted = state.receive(
      .frame(
        id: 2, inputSequence: 0,
        viewport: Size(width: .infinity, height: 600), commands: [.pushClip(.zero), .popClip]))
    #expect(!badAccepted)
    #expect(!state.requestOutstanding)
    #expect(state.latest?.viewport == viewport)
    let clipAccepted = state.receive(.frame(id: 3, inputSequence: 0, viewport: viewport, commands: [.popClip]))
    #expect(!clipAccepted)
    state.requestOutstanding = true
    let nextAccepted = state.receive(
      .frame(id: 4, inputSequence: 0, viewport: Size(width: 400, height: 300), commands: []))
    #expect(nextAccepted)
    #expect(state.latest?.viewport.width == 400)
    #expect(!state.requestOutstanding)
  }
}
