import AppKit

extension AppDelegate {
  @objc func showSettings() {
    let controller = settings ?? SettingsController(app: self)
    settings = controller
    controller.show()
  }
}

/// The Settings window (⌘,): where backups go, and both kinds of updates. Buttons call the app's own actions.
final class SettingsController: NSObject {
  private let window: NSWindow
  private let thisMacRadio: NSButton
  private let folderRadio: NSButton
  private let locationLabel: NSTextField
  private let versionLabel = NSTextField(labelWithString: "")
  private let autoCheckBox = NSButton(checkboxWithTitle: "Check for DoopBox updates when it opens (once a day)", target: nil, action: nil)

  init(app: AppDelegate) {
    func heading(_ t: String) -> NSTextField {
      let l = NSTextField(labelWithString: t)
      l.font = .systemFont(ofSize: 13, weight: .semibold)
      return l
    }
    func caption(_ t: String) -> NSTextField {
      let l = NSTextField(wrappingLabelWithString: t)
      l.font = .systemFont(ofSize: 11)
      l.textColor = .secondaryLabelColor
      l.preferredMaxLayoutWidth = 380
      return l
    }
    func divider() -> NSBox {
      let b = NSBox()
      b.boxType = .separator
      b.widthAnchor.constraint(equalToConstant: 392).isActive = true
      return b
    }
    func row(_ views: [NSView]) -> NSStackView {
      let r = NSStackView(views: views)
      r.spacing = 8
      return r
    }
    func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: app, action: action) }

    thisMacRadio = NSButton(radioButtonWithTitle: "This Mac", target: app, action: #selector(AppDelegate.backupsOnThisMac))
    folderRadio = NSButton(radioButtonWithTitle: "A folder — iCloud Drive, a NAS…", target: app,
                           action: #selector(AppDelegate.chooseBackupFolder))
    locationLabel = caption("")

    let content: [NSView] = [
      heading("Backups"),
      caption("Taken when you quit (once a day) and before updates. The last 7 are kept."),
      thisMacRadio,
      folderRadio,
      locationLabel,
      row([button("Back Up Now", #selector(AppDelegate.backUpNow)),
           button("Show in Finder", #selector(AppDelegate.openBackups))]),
      divider(),
      heading("Updates"),
      versionLabel,
      row([button("Check for Doop Updates…", #selector(AppDelegate.checkForUpdates))]),
      NSTextField(labelWithString: "DoopBox " + Config.appVersion),
      row([button("Check for DoopBox Updates…", #selector(AppDelegate.checkForDoopBoxUpdates))]),
      autoCheckBox,
    ]
    let stack = NSStackView(views: content)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 10
    for (index, space) in [0: 4.0, 5: 16, 7: 4, 9: 18, 10: 4] as [Int: CGFloat] {
      stack.setCustomSpacing(space, after: content[index])
    }
    stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 24, right: 24)
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.widthAnchor.constraint(equalToConstant: 440).isActive = true

    window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Settings"
    window.appearance = NSAppearance(named: .darkAqua)
    window.isReleasedWhenClosed = false
    window.contentView = stack
    window.setContentSize(stack.fittingSize)
    window.center()
    super.init()

    autoCheckBox.target = self
    autoCheckBox.action = #selector(toggleAutoCheck)
  }

  func show() {
    refresh()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  func refresh() {
    let folder = BackupLocation.chosenFolder
    thisMacRadio.state = folder == nil ? .on : .off
    folderRadio.state = folder == nil ? .off : .on
    locationLabel.stringValue = (BackupLocation.current.path as NSString).abbreviatingWithTildeInPath
    versionLabel.stringValue = "Doop " + (Config.read(".version") ?? "—")
    autoCheckBox.state = SelfUpdate.autoCheckEnabled ? .on : .off
  }

  @objc private func toggleAutoCheck() {
    SelfUpdate.autoCheckEnabled = autoCheckBox.state == .on
  }
}
