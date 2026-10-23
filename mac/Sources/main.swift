// DoopBox — runs the open-source Doop locally: starts its server on launch, shows its UI in a WebKit window,
// and stops the server on quit (⌘Q). The bundled doopbox.sh does the actual work. Build: ../build.sh
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
