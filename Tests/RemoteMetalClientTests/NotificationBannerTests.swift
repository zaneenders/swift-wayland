import AppKit
@testable import RemoteMetalClient
import Testing

@Suite("Client notification banner")
@MainActor
struct NotificationBannerTests {
  @Test func bannerCanBeDismissedAndShownAgainWithoutTakingFocus() {
    let banner = NotificationBanner(frame: NSRect(x: 0, y: 0, width: 500, height: 60))
    #expect(banner.isHidden)
    #expect(!banner.acceptsFirstResponder)
    banner.show("Paste failed")
    #expect(!banner.isHidden)
    let label = banner.subviews.compactMap { $0 as? NSTextField }.first
    #expect(label?.stringValue == "Paste failed")
    let button = banner.subviews.compactMap { $0 as? NSButton }.first
    #expect(button?.refusesFirstResponder == true)
    button?.performClick(nil)
    #expect(banner.isHidden)
    banner.show("Disconnected")
    #expect(!banner.isHidden)
    #expect(label?.stringValue == "Disconnected")
  }
}
