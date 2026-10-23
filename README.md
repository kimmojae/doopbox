# DoopBox

**Run the open-source [Doop](https://github.com/kgoedecke/doop) locally on your Mac, like a desktop app**

**English** · [한국어](README.ko.md)

> Unofficial community project. Not affiliated with or endorsed by Doop.

DoopBox lets you use Doop on your Mac like a desktop app, running locally on your own machine. Open the app and Doop starts; quit and it stops. It also takes care of first-time setup, updates and backups.

Doop also has its own [official desktop app](https://github.com/kgoedecke/doop/releases), which opens the hosted service at doop.design. DoopBox is the local alternative: it runs Doop's own open-source setup on your Mac.

## Install

1. Download the latest `DoopBox-<version>.dmg` from [Releases](https://github.com/kimmojae/doopbox/releases), open it, and drag DoopBox into Applications.
2. The app isn't notarized, so macOS blocks it the first time. Open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**. Or run this once in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/DoopBox.app
   ```

You need macOS 14 or newer, plus Node.js 22+ and git. Backups and updates are under Settings (⌘,).

## License

The code here is [MIT](LICENSE). Doop is a separate project under AGPL-3.0 and isn't included: DoopBox downloads it from Doop's own repository on first launch. The "Doop" name and logo belong to their owner and aren't covered by either license. If this ever causes a problem, I'll take action or remove the project.
