import AppKit

/// Loading screen — the logo in the middle slowly pulses, with a spinner and a status line below.
/// Covers the window while the server is down; removed once a Doop page has loaded.
final class LoadingView: NSView {
  let logo = NSImageView()
  let spinner = NSProgressIndicator()
  let label = NSTextField(labelWithString: "")
  private var progressTimer: Timer?

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = ink.cgColor

    logo.image = NSApp.applicationIconImage
    logo.imageScaling = .scaleProportionallyUpOrDown
    logo.wantsLayer = true
    spinner.style = .spinning
    spinner.controlSize = .small
    spinner.appearance = NSAppearance(named: .darkAqua)
    label.isHidden = true  // A normal launch shows only the logo and spinner

    let row = NSStackView(views: [spinner, label])
    row.spacing = 8
    let stack = NSStackView(views: [logo, row])
    stack.orientation = .vertical
    stack.spacing = 22
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      logo.widthAnchor.constraint(equalToConstant: 96),
      logo.heightAnchor.constraint(equalToConstant: 96),
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
    ])
  }
  required init?(coder: NSCoder) { fatalError() }

  /// Shows a line under the logo, in small caps with wide letter spacing.
  func status(_ text: String, color: NSColor = NSColor(white: 0.55, alpha: 1)) {
    label.attributedStringValue = NSAttributedString(string: text.uppercased(), attributes: [
      .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
      .kern: 2.2,
      .foregroundColor: color,
    ])
    label.isHidden = false
  }

  func start() {
    spinner.startAnimation(nil)
    let pulse = CABasicAnimation(keyPath: "opacity")
    pulse.fromValue = 1.0
    pulse.toValue = 0.45
    pulse.duration = 1.1
    pulse.autoreverses = true
    pulse.repeatCount = .infinity
    pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    logo.layer?.add(pulse, forKey: "pulse")
  }

  func fail(_ text: String) {
    stopWatchingProgress()
    spinner.stopAnimation(nil)
    spinner.isHidden = true
    logo.layer?.removeAnimation(forKey: "pulse")
    logo.alphaValue = 0.5
    status(text, color: NSColor(white: 0.7, alpha: 1))
  }

  func retry() {
    label.isHidden = true
    spinner.isHidden = false
    logo.alphaValue = 1
    start()
  }

  /// While a long job runs, show its current step — doopbox.sh writes it to the `status` file.
  func watchProgress() {
    progressTimer?.invalidate()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
      if let step = Config.read("status") { self?.status(step) }
    }
  }

  func stopWatchingProgress() {
    progressTimer?.invalidate()
    progressTimer = nil
  }

  func dismiss() {
    stopWatchingProgress()
    fadeOut(duration: 0.35) { self.removeFromSuperview() }
  }
}
