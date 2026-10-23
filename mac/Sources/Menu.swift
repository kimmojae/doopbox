import AppKit

// A menu is required for ⌘C, ⌘V, ⌘Z to work in the web view.
extension AppDelegate: NSMenuItemValidation {
  func buildMenu() {
    let main = NSMenu()
    func sub(_ title: String, _ items: [NSMenuItem]) {
      let item = NSMenuItem()
      let menu = NSMenu(title: title)
      items.forEach(menu.addItem)
      item.submenu = menu
      main.addItem(item)
    }
    /// A menu item; ours (target self) unless it's a standard action that goes up the responder chain.
    func it(_ title: String, _ action: Selector?, _ key: String, _ mods: NSEvent.ModifierFlags = .command,
            ours: Bool = false) -> NSMenuItem {
      let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
      i.keyEquivalentModifierMask = mods
      if ours { i.target = self }
      return i
    }

    sub("DoopBox", [
      it("Check for DoopBox Updates…", #selector(checkForDoopBoxUpdates), "", ours: true),
      it("Check for Doop Updates…", #selector(checkForUpdates), "", ours: true),
      .separator(),
      it("Settings…", #selector(showSettings), ",", ours: true),
      .separator(),
      it("Hide DoopBox", #selector(NSApplication.hide(_:)), "h"),
      .separator(),
      it("Quit DoopBox", #selector(NSApplication.terminate(_:)), "q"),
    ])
    sub("Edit", [
      it("Undo", Selector(("undo:")), "z"),
      it("Redo", Selector(("redo:")), "z", [.command, .shift]),
      .separator(),
      it("Cut", #selector(NSText.cut(_:)), "x"),
      it("Copy", #selector(NSText.copy(_:)), "c"),
      it("Paste", #selector(NSText.paste(_:)), "v"),
      it("Select All", #selector(NSText.selectAll(_:)), "a"),
    ])
    sub("View", [
      it("Reload", #selector(reload), "r", ours: true),
      .separator(),
      it("Back", #selector(goBack), "[", ours: true),
      it("Forward", #selector(goForward), "]", ours: true),
    ])
    sub("Window", [
      it("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
      it("Close", #selector(NSWindow.performClose(_:)), "w"),
    ])
    NSApp.mainMenu = main
  }

  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    switch item.action {
    case #selector(goBack): return web.canGoBack
    case #selector(goForward): return web.canGoForward
    default: return true
    }
  }
}
