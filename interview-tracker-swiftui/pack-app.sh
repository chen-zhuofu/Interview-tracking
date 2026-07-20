#!/bin/bash
# Rebuild InterviewTracker.app on the Desktop with the current code + Langbridge icon.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Desktop/InterviewTracker.app"
ICON="$ROOT/AppBundle/AppIcon.icns"

echo "Building release…"
cd "$ROOT"
swift build -c release

echo "Packaging $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/.build/release/InterviewTracker" "$APP/Contents/MacOS/InterviewTracker"
chmod +x "$APP/Contents/MacOS/InterviewTracker"

# SwiftPM resource bundle (logo etc.) — Bundle.module looks for it in Resources.
if [ -d "$ROOT/.build/release/InterviewTracker_InterviewTracker.bundle" ]; then
  cp -R "$ROOT/.build/release/InterviewTracker_InterviewTracker.bundle" "$APP/Contents/Resources/"
fi

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh-Hans</string>
	<key>CFBundleExecutable</key>
	<string>InterviewTracker</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.langbridge.InterviewTracker</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>InterviewTracker</string>
	<key>CFBundleDisplayName</key>
	<string>面试追踪</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

xattr -cr "$APP" 2>/dev/null || true
touch "$APP"
echo "Done. Double-click InterviewTracker on your Desktop."
