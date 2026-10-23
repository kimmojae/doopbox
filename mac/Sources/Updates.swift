import AppKit

// MARK: Doop updates — doopbox.sh moves to the newest release tag, with a backup first and a rollback on failure.

extension AppDelegate {
  @objc func checkForUpdates() {
    DispatchQueue.global().async {
      let (status, latest) = Script.capture("check")
      DispatchQueue.main.async {
        switch status {
        case Script.updateAvailable:
          let choice = alert("Doop \(latest) is available",
                             "DoopBox will back up your data, update, and restart the server. If the new version doesn’t start, it goes back to the previous one.",
                             buttons: ["Update", "Later"])
          if choice == .alertFirstButtonReturn { self.applyUpdate(latest) }
        case 0:
          alert("Doop is up to date", "You’re running \(latest).")
        default:
          alert("Couldn’t check for updates", "Check your connection and try again.")
        }
      }
    }
  }

  func applyUpdate(_ tag: String) {
    runWithOverlay("Updating to \(tag)", "update", failure: (
      "The update didn’t work",
      "DoopBox went back to the previous version and restored your data from the backup."))
  }

  @objc func checkForDoopBoxUpdates() { SelfUpdate.check(manual: true) }
}

// MARK: DoopBox's own updates — a GitHub release with a DMG. The app only tells; the person replaces the app.

enum SelfUpdate {
  private static let defaults = UserDefaults.standard
  private static let autoCheckKey = "autoCheckDoopBox"
  private static let lastCheckKey = "lastDoopBoxCheck"
  private static let notifiedKey = "notifiedVersion"

  static var autoCheckEnabled: Bool {
    get { defaults.object(forKey: autoCheckKey) as? Bool ?? true }
    set { defaults.set(newValue, forKey: autoCheckKey) }
  }

  /// Once a day at most, a few seconds after launch so it doesn't land on top of the loading screen.
  static func autoCheckIfDue() {
    guard autoCheckEnabled else { return }
    if let last = defaults.object(forKey: lastCheckKey) as? Date, Date().timeIntervalSince(last) < 86_400 { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
      defaults.set(Date(), forKey: lastCheckKey)
      check(manual: false)
    }
  }

  /// A manual check always answers; an automatic one only speaks up about a version it hasn't mentioned yet.
  static func check(manual: Bool) {
    fetchLatest { result in
      switch result {
      case .success(let release?) where isNewer(release.tag, than: Config.appVersion):
        if !manual && defaults.string(forKey: notifiedKey) == release.tag { return }
        defaults.set(release.tag, forKey: notifiedKey)
        let shown = release.tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let choice = alert("DoopBox \(shown) is available",
                           "You have \(Config.appVersion). Download the new DMG, quit DoopBox, and drag the new app into Applications. Your data and backups stay where they are.",
                           buttons: ["Download", "Later"])
        if choice == .alertFirstButtonReturn { NSWorkspace.shared.open(release.page) }
      case .success:
        if manual { alert("DoopBox is up to date", "You’re on \(Config.appVersion).") }
      case .failure:
        if manual { alert("Couldn’t check for updates", "Check your connection and try again.") }
      }
    }
  }

  /// The latest published release, or nil when none has been published yet. Calls back on the main thread.
  private static func fetchLatest(_ done: @escaping (Result<(tag: String, page: URL)?, Error>) -> Void) {
    var req = URLRequest(url: Config.releasesURL)
    req.timeoutInterval = 10
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    URLSession.shared.dataTask(with: req) { data, resp, err in
      DispatchQueue.main.async {
        if let err = err { done(.failure(err)); return }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { done(.success(nil)); return }  // nothing published yet
        guard status == 200, let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else {
          done(.failure(NSError(domain: "DoopBox", code: status))); return
        }
        done(.success((tag, page)))
      }
    }.resume()
  }

  /// Numeric comparison of "1.2.10"-style versions; a leading "v" is ignored.
  static func isNewer(_ a: String, than b: String) -> Bool {
    func parts(_ v: String) -> [Int] {
      v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
    let x = parts(a), y = parts(b)
    for i in 0..<max(x.count, y.count) {
      let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
      if p != q { return p > q }
    }
    return false
  }
}
