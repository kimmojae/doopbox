#!/usr/bin/env bash
# Builds DoopBox.app and installs it to /Applications: ./build.sh
# Build only, without installing: ./build.sh build/DoopBox.app
# Intel + Apple Silicon in one app (used for the DMG): UNIVERSAL=1 ./build.sh build/DoopBox.app
set -euo pipefail
cd "$(dirname "$0")"
INSTALL=/Applications/DoopBox.app
VERSION=$(tr -d '[:space:]' < VERSION)
OUT="${1:-build/DoopBox.app}"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
if [ "${UNIVERSAL:-}" = 1 ]; then
  for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos14.0" -o "$OUT/Contents/MacOS/DoopBox-$arch" Sources/*.swift
  done
  lipo -create -output "$OUT/Contents/MacOS/DoopBox" "$OUT"/Contents/MacOS/DoopBox-{arm64,x86_64}
  rm "$OUT"/Contents/MacOS/DoopBox-{arm64,x86_64}
else
  swiftc -O -o "$OUT/Contents/MacOS/DoopBox" Sources/*.swift
fi
cp doopbox.sh "$OUT/Contents/Resources/doopbox.sh"
# Icon: icon-default.png, unless a local (git-ignored) icon.png is there.
ICON=icon-default.png
[ -f icon.png ] && ICON=icon.png
tmp=$(mktemp -d); mkdir "$tmp/DoopBox.iconset"
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$ICON" --out "$tmp/DoopBox.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$ICON" --out "$tmp/DoopBox.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$tmp/DoopBox.iconset" -o "$OUT/Contents/Resources/DoopBox.icns"; rm -rf "$tmp"
cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>DoopBox</string>
  <key>CFBundleDisplayName</key><string>DoopBox</string>
  <key>CFBundleIdentifier</key><string>com.hjkim.doopbox</string>
  <key>CFBundleExecutable</key><string>DoopBox</string>
  <key>CFBundleIconFile</key><string>DoopBox</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
codesign --force -s - "$OUT" >/dev/null 2>&1
if [ $# -eq 0 ]; then
  osascript -e 'tell application id "com.hjkim.doopbox" to quit' >/dev/null 2>&1 || true
  sleep 2
  rm -rf "$INSTALL" && mv "$OUT" "$INSTALL" && rm -rf build
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL"
  echo "Installed: $INSTALL"
else
  echo "$OUT"
fi
