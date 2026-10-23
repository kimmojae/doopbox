import Foundation

/// Paths and addresses shared across the app. DOOPBOX_HOME, DOOPBOX_PORT and DOOPBOX_RELEASES_URL override the
/// defaults — doopbox.sh reads the same variables — which is how a second copy can be run and tested.
enum Config {
  private static let env = ProcessInfo.processInfo.environment

  static let port = env["DOOPBOX_PORT"] ?? "4300"
  static let doopURL = URL(string: "http://localhost:\(port)")!
  static let home = env["DOOPBOX_HOME"] ?? NSString(string: "~/Library/Application Support/DoopBox").expandingTildeInPath
  static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
  /// DoopBox's own releases on GitHub (the DMGs are attached to them).
  static let releasesURL = URL(string: env["DOOPBOX_RELEASES_URL"]
    ?? "https://api.github.com/repos/kimmojae/doopbox/releases/latest")!

  static func path(_ name: String) -> String { home + "/" + name }

  /// One of the small text files doopbox.sh keeps in `home` (.version, status, backup-dir…); nil if missing or empty.
  static func read(_ name: String) -> String? {
    guard let s = try? String(contentsOfFile: path(name), encoding: .utf8) else { return nil }
    let text = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }
}

/// The bundled doopbox.sh does the real work — setup, start/stop, updates, backups. Calls block; run them off the main thread.
enum Script {
  static let path = Bundle.main.path(forResource: "doopbox", ofType: "sh")!

  // Exit codes beyond 0/1; doopbox.sh defines the same.
  static let updateAvailable: Int32 = 10
  static let nodeMissing: Int32 = 20
  static let gitMissing: Int32 = 21

  @discardableResult static func run(_ args: String...) -> Int32 {
    let p = process(args)
    do { try p.run() } catch { return 1 }
    p.waitUntilExit()
    return p.terminationStatus
  }

  /// Like `run`, but also returns stdout (trimmed).
  static func capture(_ args: String...) -> (status: Int32, output: String) {
    let p = process(args)
    let pipe = Pipe()
    p.standardOutput = pipe
    do { try p.run() } catch { return (1, "") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
  }

  /// Runs the commands one after another in the background, outliving the app (used on quit).
  static func runDetached(_ commands: [String]) {
    let chain = commands.map { "/bin/bash '\(path)' \($0)" }.joined(separator: "; ")
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = ["-c", "nohup sh -c \"\(chain)\" >/dev/null 2>&1 &"]
    try? p.run()
    p.waitUntilExit()
  }

  private static func process(_ args: [String]) -> Process {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = [path] + args
    return p
  }
}
