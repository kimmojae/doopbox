import AppKit
import WebKit

/// The main window: Doop's web UI in a WebKit view (the same engine as Safari), covered by the loading screen
/// or the first-run checklist until the server is up. Closing the window only hides it; quitting stops the server.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: NSWindow!
  var web: WKWebView!
  /// The loading screen currently covering the window, if any (see `webView(_:didFinish:)`).
  var loading: LoadingView?
  var onboarding: OnboardingView?
  var settings: SettingsController?
  private var navObservers: [NSKeyValueObservation] = []
  private var backButton: NSButton!
  private var forwardButton: NSButton!

  func applicationDidFinishLaunching(_ notification: Notification) {
    buildMenu()
    buildWindow()
    let overlay = cover(with: LoadingView())
    overlay.start()
    loading = overlay
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()

    begin()
    SelfUpdate.autoCheckIfDue()
  }

  private func buildWindow() {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .default()
    web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = self
    web.uiDelegate = self
    web.allowsBackForwardNavigationGestures = true
    web.underPageBackgroundColor = ink
    web.setValue(false, forKey: "drawsBackground")

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "DoopBox"
    window.appearance = NSAppearance(named: .darkAqua)
    window.titlebarAppearsTransparent = true
    window.backgroundColor = ink
    window.center()
    window.setFrameAutosaveName("DoopBoxMain")
    window.delegate = self

    let root = NSView()
    web.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(web)
    web.pinEdges(to: root)
    window.contentView = root
    addNavButtons()
  }

  /// Lays a full-window view over the web view (the loading screen, the checklist).
  @discardableResult func cover<V: NSView>(with view: V) -> V {
    let root = window.contentView!
    view.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(view)
    view.pinEdges(to: root)
    return view
  }

  // MARK: Starting the server

  /// A first run needs Node.js and git, so it starts with the checklist; after that, straight to the server.
  var needsSetup: Bool {
    let fm = FileManager.default
    return !fm.fileExists(atPath: Config.path("app/dist")) || !fm.fileExists(atPath: Config.path(".env"))
  }

  func begin() {
    guard needsSetup else { startServer(); return }
    let checklist = onboarding ?? cover(with: OnboardingView())
    onboarding = checklist
    checklist.onReady = { [weak self] in self?.startServer() }
    checklist.startChecking()
  }

  func startServer() {
    loading?.watchProgress()
    DispatchQueue.global().async {
      let code = Script.run("start")
      DispatchQueue.main.async {
        self.loading?.stopWatchingProgress()
        switch code {
        case 0:
          self.web.load(URLRequest(url: Config.doopURL))
        case Script.nodeMissing:
          self.loading?.fail("Node.js not found · Install it, then ⌘R")
          if alert("DoopBox needs Node.js", "Install it from nodejs.org (or with `brew install node`), then press ⌘R in DoopBox.",
                   buttons: ["Open nodejs.org", "Close"]) == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://nodejs.org")!)
          }
        case Script.gitMissing:
          self.loading?.fail("git not found · Install it, then ⌘R")
          alert("DoopBox needs git", "macOS can install Apple’s developer tools, which include git. If a window offered to install them, accept it; otherwise run `xcode-select --install` in Terminal. Then press ⌘R in DoopBox.")
        default:
          self.loading?.fail("Server didn’t start · See server.log, then ⌘R")
        }
      }
    }
  }

  /// Covers the window with a loading screen while a doopbox.sh command takes the server down (update, backup),
  /// then reloads the page, which removes the cover.
  func runWithOverlay(_ statusText: String, _ command: String, failure: (title: String, detail: String)) {
    let overlay = cover(with: LoadingView())
    overlay.status(statusText)
    overlay.start()
    loading = overlay
    overlay.watchProgress()
    DispatchQueue.global().async {
      let ok = Script.run(command) == 0
      DispatchQueue.main.async {
        overlay.stopWatchingProgress()
        if !ok {
          overlay.fail(failure.title)
          alert(failure.title, failure.detail)
        }
        self.web.load(URLRequest(url: Config.doopURL))
      }
    }
  }

  @objc func reload() {
    if web.url?.host == "localhost" { web.reload(); return }
    // The server didn't come up earlier — try again
    loading?.retry()
    begin()
  }

  // MARK: Window and app lifecycle

  // Closing the window (red button, ⌘W) only hides it — the server stops only on ⌘Q. Clicking the Dock icon shows it again.
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { window.makeKeyAndOrderFront(nil) }
    return true
  }

  // Stop the server on quit, then take the day's backup (the folder is only safe to copy once the server is down).
  // Detached so the app exits at once; the script gives PGlite a moment to flush.
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    Script.runDetached(["stop", "backup"])
    return .terminateNow
  }

  // MARK: Back / forward

  // Buttons in the title bar, right of the traffic lights. A toolbar would make the title bar taller, so use an accessory.
  // In-page (SPA) navigation also changes canGoBack, so keep the enabled state in sync via KVO.
  private func addNavButtons() {
    func navButton(_ symbol: String, _ label: String, _ action: Selector) -> NSButton {
      let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)!, target: self, action: action)
      b.isBordered = false
      b.toolTip = label
      b.contentTintColor = NSColor(white: 0.85, alpha: 1)
      return b
    }
    backButton = navButton("chevron.left", "Back", #selector(goBack))
    forwardButton = navButton("chevron.right", "Forward", #selector(goForward))
    // Accessory views ignore Auto Layout sizing, so set the frame explicitly (otherwise the width is 0 and nothing shows).
    let bar = NSView(frame: NSRect(x: 0, y: 0, width: 64, height: 28))
    backButton.frame = NSRect(x: 8, y: 1, width: 26, height: 26)
    forwardButton.frame = NSRect(x: 36, y: 1, width: 26, height: 26)
    bar.addSubview(backButton)
    bar.addSubview(forwardButton)
    let accessory = NSTitlebarAccessoryViewController()
    accessory.view = bar
    accessory.layoutAttribute = .left
    window.addTitlebarAccessoryViewController(accessory)
    updateNavButtons()
    navObservers = [
      web.observe(\.canGoBack) { [weak self] _, _ in self?.updateNavButtons() },
      web.observe(\.canGoForward) { [weak self] _, _ in self?.updateNavButtons() },
    ]
  }

  private func updateNavButtons() {
    backButton.isEnabled = web.canGoBack
    forwardButton.isEnabled = web.canGoForward
  }

  @objc func goBack() { web.goBack() }
  @objc func goForward() { web.goForward() }
}
