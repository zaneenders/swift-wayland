import AppKit

/// Client-owned overlay: remains available even when the daemon cannot render.
@MainActor
final class NotificationBanner: NSView {
  private let label = NSTextField(wrappingLabelWithString: "")
  private let dismissButton = NSButton(title: "Dismiss", target: nil, action: nil)

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    layer?.cornerRadius = 8
    label.font = .systemFont(ofSize: 13)
    label.textColor = .labelColor
    dismissButton.target = self
    dismissButton.action = #selector(dismiss)
    dismissButton.bezelStyle = .rounded
    dismissButton.refusesFirstResponder = true
    for child in [label, dismissButton] {
      child.translatesAutoresizingMaskIntoConstraints = false
      addSubview(child)
    }
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
      dismissButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
      dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    dismissButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    isHidden = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func show(_ message: String) {
    label.stringValue = message
    isHidden = false
    NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
      .announcement: message,
      .priority: NSAccessibilityPriorityLevel.high.rawValue,
    ])
  }

  @objc func dismiss() {
    isHidden = true
  }
}
