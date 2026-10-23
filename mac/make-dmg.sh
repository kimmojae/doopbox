#!/usr/bin/env bash
# Builds dist/DoopBox-<version>.dmg: a universal (Intel + Apple Silicon) app plus an Applications shortcut.
# Ad-hoc signed, not notarized — macOS blocks the first launch until it's allowed (see README → Install).
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(tr -d '[:space:]' < VERSION)
DMG="dist/DoopBox-$VERSION.dmg"
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT

UNIVERSAL=1 ./build.sh "$stage/DoopBox.app" >/dev/null
ln -s /Applications "$stage/Applications"
mkdir -p dist; rm -f "$DMG"
hdiutil create -quiet -volname "DoopBox" -srcfolder "$stage" -ov -format UDZO "$DMG"
echo "$DMG"
shasum -a 256 "$DMG"
