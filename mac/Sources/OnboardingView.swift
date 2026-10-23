import AppKit

/// What a first run needs. The keys match the lines `doopbox.sh doctor` prints.
struct Requirement {
  let key: String
  let title: String
  let why: String
  let required: Bool
  let fix: String
}

let requirements = [
  Requirement(key: "node", title: "Node.js 22 or newer", why: "Runs the Doop server", required: true, fix: "Get Node.js"),
  Requirement(key: "git", title: "git", why: "Downloads Doop", required: true, fix: "Install"),
  Requirement(key: "chrome", title: "Google Chrome", why: "Optional · used for frame screenshots", required: false, fix: "Get Chrome"),
]

/// First-run checklist, shown until Node.js and git are available. It re-checks every few seconds and calls
/// `onReady` by itself once everything required is there.
final class OnboardingView: NSView {
  var onReady: () -> Void = {}
  private let list = NSStackView()
  private var timer: Timer?
  private var checking = false

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = ink.cgColor

    let logo = NSImageView(image: NSApp.applicationIconImage)
    logo.imageScaling = .scaleProportionallyUpOrDown
    let title = NSTextField(labelWithString: "Before we start")
    title.font = .systemFont(ofSize: 22, weight: .semibold)
    title.textColor = .white
    let sub = NSTextField(wrappingLabelWithString: "DoopBox needs a few things on this Mac. It carries on by itself once they’re there.")
    sub.font = .systemFont(ofSize: 13)
    sub.textColor = NSColor(white: 0.6, alpha: 1)
    sub.alignment = .center
    sub.preferredMaxLayoutWidth = 420
    list.orientation = .vertical
    list.spacing = 10
    list.alignment = NSLayoutConstraint.Attribute.leading

    let stack = NSStackView(views: [logo, title, sub, list])
    stack.orientation = .vertical
    stack.alignment = NSLayoutConstraint.Attribute.centerX
    stack.spacing = 12
    stack.setCustomSpacing(26, after: sub)
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      logo.widthAnchor.constraint(equalToConstant: 80),
      logo.heightAnchor.constraint(equalToConstant: 80),
      list.widthAnchor.constraint(equalToConstant: 420),
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
    ])
  }
  required init?(coder: NSCoder) { fatalError() }

  func startChecking() {
    alphaValue = 1
    isHidden = false
    timer?.invalidate()
    check()
    timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.check() }
  }

  private func check() {
    guard !checking else { return }
    checking = true
    DispatchQueue.global().async {
      let (status, report) = Script.capture("doctor")
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.checking = false
        guard !self.isHidden else { return }
        self.show(Self.parse(report))
        guard status == 0 else { return }
        self.timer?.invalidate()
        self.timer = nil
        self.fadeOut(duration: 0.3) { self.isHidden = true }
        self.onReady()
      }
    }
  }

  /// `doctor` prints one "key<TAB>state<TAB>detail" line per tool.
  private static func parse(_ report: String) -> [String: (state: String, detail: String)] {
    var found: [String: (state: String, detail: String)] = [:]
    for line in report.split(separator: "\n") {
      let p = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
      if p.count == 3 { found[p[0]] = (p[1], p[2]) }
    }
    return found
  }

  private func show(_ found: [String: (state: String, detail: String)]) {
    list.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for r in requirements {
      let ok = found[r.key]?.state == "ok"
      let symbol = ok ? "checkmark.circle.fill" : (r.required ? "xmark.circle.fill" : "circle.dashed")
      let tint: NSColor = ok ? .systemGreen : (r.required ? .systemRed : NSColor(white: 0.45, alpha: 1))
      let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!)
      icon.contentTintColor = tint
      icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
      icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

      let name = NSTextField(labelWithString: r.title)
      name.font = .systemFont(ofSize: 13, weight: .medium)
      name.textColor = .white
      let detail = NSTextField(labelWithString: ok ? (found[r.key]?.detail ?? "") : (r.required ? (found[r.key]?.detail ?? "Not found") : r.why))
      detail.font = .systemFont(ofSize: 11)
      detail.textColor = NSColor(white: 0.55, alpha: 1)
      let text = NSStackView(views: [name, detail])
      text.orientation = .vertical
      text.alignment = NSLayoutConstraint.Attribute.leading
      text.spacing = 1
      text.setContentHuggingPriority(.defaultLow, for: .horizontal)

      var parts: [NSView] = [icon, text]
      if !ok {
        let b = NSButton(title: r.fix, target: self, action: #selector(fixPressed(_:)))
        b.identifier = NSUserInterfaceItemIdentifier(r.key)
        b.bezelStyle = .rounded
        b.controlSize = .small
        parts.append(b)
      }
      let row = NSStackView(views: parts)
      row.distribution = .fill
      row.spacing = 12
      row.alignment = NSLayoutConstraint.Attribute.centerY
      row.widthAnchor.constraint(equalToConstant: 420).isActive = true
      list.addArrangedSubview(row)
    }
  }

  @objc private func fixPressed(_ b: NSButton) {
    switch b.identifier?.rawValue {
    case "node": NSWorkspace.shared.open(URL(string: "https://nodejs.org")!)
    case "chrome": NSWorkspace.shared.open(URL(string: "https://www.google.com/chrome/")!)
    case "git":
      // Asks macOS to install Apple's developer tools, which include git.
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
      p.arguments = ["--install"]
      try? p.run()
    default: break
    }
  }
}
