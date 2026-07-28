#!/bin/bash
# Build a distributable universal macOS app, DMG, ZIP, and checksums.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="InterviewTracker"
VERSION="${1:-1.0.0}"
OUTPUT_DIR_INPUT="${2:-$ROOT/dist}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must use semantic version format, for example: 1.0.0" >&2
    exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "BUILD_NUMBER must be numeric." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR_INPUT"
OUTPUT_DIR="$(cd "$OUTPUT_DIR_INPUT" && pwd)"
OUTPUT_APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
DMG_FILENAME="$APP_NAME-$VERSION-macos-universal.dmg"
ZIP_FILENAME="$APP_NAME-$VERSION-macos-universal.zip"
CHECKSUM_FILENAME="SHA256SUMS.txt"
DMG_PATH="$OUTPUT_DIR/$DMG_FILENAME"
ZIP_PATH="$OUTPUT_DIR/$ZIP_FILENAME"
CHECKSUM_PATH="$OUTPUT_DIR/$CHECKSUM_FILENAME"
ICON_PATH="$ROOT/AppBundle/AppIcon.icns"
WORK_DIR="$(mktemp -d /tmp/interview-tracker-release.XXXXXX)"
APP_PATH="$WORK_DIR/$APP_NAME.app"
DMG_STAGING_DIR="$WORK_DIR/dmg"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Building universal release for Apple Silicon and Intel…"
cd "$ROOT"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BINARY_PATH="$BIN_DIR/$APP_NAME"
RESOURCE_BUNDLE_PATH="$BIN_DIR/InterviewTracker_InterviewTracker.bundle"

if [[ ! -x "$BINARY_PATH" ]]; then
    echo "Built executable not found: $BINARY_PATH" >&2
    exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE_PATH" ]]; then
    echo "SwiftPM resource bundle not found: $RESOURCE_BUNDLE_PATH" >&2
    exit 1
fi

if [[ ! -f "$ICON_PATH" ]]; then
    echo "App icon not found: $ICON_PATH" >&2
    exit 1
fi

echo "Assembling app bundle…"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$ICON_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"

cp -R "$RESOURCE_BUNDLE_PATH" "$APP_PATH/Contents/Resources/"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Interview Tracker</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.langbridge.InterviewTracker</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null
xattr -cr "$APP_PATH"

SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Applying an ad-hoc signature…"
    codesign --force --sign - "$APP_PATH"
else
    echo "Signing with Developer ID identity: $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
fi
codesign --verify --deep --strict "$APP_PATH"

rm -rf "$OUTPUT_APP_PATH"
rm -f "$DMG_PATH" "$ZIP_PATH" "$CHECKSUM_PATH"
mkdir -p "$DMG_STAGING_DIR"
ditto --norsrc --noextattr "$APP_PATH" "$DMG_STAGING_DIR/$APP_NAME.app"
xattr -cr "$DMG_STAGING_DIR/$APP_NAME.app"
codesign --verify --deep --strict "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

echo "Creating installer disk image…"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo "Creating ZIP archive and checksums…"
ditto -c -k --norsrc --noextattr --keepParent "$APP_PATH" "$ZIP_PATH"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$DMG_FILENAME" "$ZIP_FILENAME" > "$CHECKSUM_FILENAME"
)

echo
echo "Release artifacts:"
ls -lh "$DMG_PATH" "$ZIP_PATH" "$CHECKSUM_PATH"
echo
echo "Open $DMG_FILENAME, then drag $APP_NAME to Applications."
