import Testing

@testable import RemoteMetalClient

struct FrameResponseDeadlineTests {
  @Test func expiresOnlyAfterTheResponseDeadline() {
    #expect(!FrameResponseDeadline.hasExpired(since: 100, now: 109.99))
    #expect(FrameResponseDeadline.hasExpired(since: 100, now: 110))
    #expect(FrameResponseDeadline.hasExpired(since: 100, now: 120))
    #expect(!FrameResponseDeadline.hasExpired(since: 120, now: 120))
  }
}
