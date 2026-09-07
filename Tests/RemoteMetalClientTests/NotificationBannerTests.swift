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

  @Test func closeButtonStaysCompactAndMessageWraps() throws {
    for width in [320.0, 560.0, 1400.0] {
      let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 300))
      let banner = NotificationBanner(frame: .zero)
      banner.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(banner)
      NSLayoutConstraint.activate([
        banner.topAnchor.constraint(equalTo: container.topAnchor),
        banner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        banner.widthAnchor.constraint(equalToConstant: width),
      ])
      banner.show("Disconnected from the remote daemon. Close this window and reconnect to continue.")
      container.layoutSubtreeIfNeeded()
      let button = try #require(banner.subviews.compactMap { $0 as? NSButton }.first)
      let label = try #require(banner.subviews.compactMap { $0 as? NSTextField }.first)
      #expect(button.frame.width == 28)
      #expect(button.alignmentRect(forFrame: button.frame).height == 28)
      #expect(button.image != nil)
      #expect(button.accessibilityLabel() == "Dismiss notification")
      #expect(label.frame.maxX < button.frame.minX)
      #expect(banner.frame.height >= 56)
      if width == 320 {
        #expect(label.frame.height > 30)
      }
    }
  }


  @Test func successNotificationDismissesAutomatically() throws {
    let banner = NotificationBanner(frame: .zero)
    banner.show("Reconnected", success: true, dismissAfter: 0.01)
    let icon = try #require(banner.subviews.compactMap { $0 as? NSImageView }.first)
    #expect(icon.contentTintColor == .systemGreen)
    #expect(!banner.isHidden)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    #expect(banner.isHidden)
  }

  @Test func newWarningCancelsPreviousAutoDismiss() throws {
    let banner = NotificationBanner(frame: .zero)
    banner.show("Reconnected", success: true, dismissAfter: 0.01)
    banner.show("Connection lost. Reconnecting automatically…")
    let icon = try #require(banner.subviews.compactMap { $0 as? NSImageView }.first)
    #expect(icon.contentTintColor == .systemOrange)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    #expect(!banner.isHidden)
  }

}
