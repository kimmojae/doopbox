import AppKit

/// The app's background — Doop's own near-black.
let ink = NSColor(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1)

/// A modal alert. Returns which button was pressed; with no buttons given, macOS shows a single OK.
@discardableResult
func alert(_ title: String, _ info: String = "", buttons: [String] = []) -> NSApplication.ModalResponse {
  let a = NSAlert()
  a.messageText = title
  a.informativeText = info
  buttons.forEach { a.addButton(withTitle: $0) }
  return a.runModal()
}

extension NSView {
  func pinEdges(to other: NSView) {
    NSLayoutConstraint.activate([
      topAnchor.constraint(equalTo: other.topAnchor),
      bottomAnchor.constraint(equalTo: other.bottomAnchor),
      leadingAnchor.constraint(equalTo: other.leadingAnchor),
      trailingAnchor.constraint(equalTo: other.trailingAnchor),
    ])
  }

  /// Fades out, then runs `completion`.
  func fadeOut(duration: TimeInterval, then completion: @escaping () -> Void) {
    NSAnimationContext.runAnimationGroup({ ctx in
      ctx.duration = duration
      animator().alphaValue = 0
    }, completionHandler: completion)
  }
}
