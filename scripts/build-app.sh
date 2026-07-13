#!/bin/bash
set -euo pipefail

APP_VERSION="${APP_VERSION-0.1.0}"
APP_BUILD="${APP_BUILD-1}"

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "APP_VERSION must be a numeric dotted semantic version (for example, 0.1.0)" >&2
  exit 1
fi

if [[ ! "$APP_BUILD" =~ ^[0-9]+$ ]]; then
  echo "APP_BUILD must contain only digits" >&2
  exit 1
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/dist/Codex Pet Usage.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/CodexPetUsage" "$CONTENTS/MacOS/CodexPetUsage"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CodexPetUsage</string>
  <key>CFBundleIdentifier</key>
  <string>ai.jimmyasks.codex-pet-usage-macos</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Pet Usage</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
