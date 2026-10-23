import AppKit

/// Where backups go: a folder the person picked (doopbox.sh keeps it in `backup-dir`), or this Mac.
enum BackupLocation {
  static var chosenFolder: String? { Config.read("backup-dir") }
  static var current: URL {
    chosenFolder.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: Config.path("backups"))
  }
}

extension AppDelegate {
  // Needs the server down to copy the database safely, so it restarts it afterwards.
  @objc func backUpNow() {
    window.makeKeyAndOrderFront(nil)
    runWithOverlay("Backing up", "backup-now", failure: (
      "The backup didn’t finish",
      "Your data is untouched. Try again, or open the backups folder to see what exists."))
  }

  @objc func chooseBackupFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.prompt = "Choose"
    panel.message = "Backups are saved in this folder instead of on this Mac, one .tar.gz per backup. Pick a folder in iCloud Drive to keep them off this Mac."
    let icloud = NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs").expandingTildeInPath
    if FileManager.default.fileExists(atPath: icloud) { panel.directoryURL = URL(fileURLWithPath: icloud) }
    guard panel.runModal() == .OK, let url = panel.url else { settings?.refresh(); return }
    DispatchQueue.global().async {
      let ok = Script.run("backup-dir", url.path) == 0
      DispatchQueue.main.async {
        self.settings?.refresh()
        if !ok { alert("Couldn’t use that folder") }
      }
    }
  }

  @objc func backupsOnThisMac() {
    DispatchQueue.global().async {
      Script.run("backup-dir", "--clear")
      DispatchQueue.main.async { self.settings?.refresh() }
    }
  }

  @objc func openBackups() {
    let dir = BackupLocation.current
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    NSWorkspace.shared.open(dir)
  }
}
