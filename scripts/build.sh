#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_NAME="Claude Code Panel"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
VERSION="1.8"
DMG_NAME="ClaudeCodePanel-${VERSION}"
VOL_NAME="Claude Code Panel Installer"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Code Panel — Build & Package v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Step 1: Generate icon ────────────────────────────────────
echo ""
echo "[1/6] Generating app icon..."
python3 "$ROOT/scripts/generate_icon.py"

# ── Step 2: Build Swift binary ──────────────────────────────
echo ""
echo "[2/6] Building Swift binary..."
cd "$ROOT"
swift build -c release --arch arm64 2>&1 | tail -3

RELEASE_BIN="$ROOT/.build/arm64-apple-macosx/release/ClaudeCodePanel"
DEBUG_BIN="$ROOT/.build/debug/ClaudeCodePanel"

if [[ -f "$RELEASE_BIN" ]]; then
    BIN_SRC="$RELEASE_BIN"
    echo "  ✓ Release build: $BIN_SRC"
elif [[ -f "$DEBUG_BIN" ]]; then
    BIN_SRC="$DEBUG_BIN"
    echo "  ⚠ Falling back to debug build: $BIN_SRC"
else
    echo "  ✗ No binary found — run swift build first"
    exit 1
fi

# Strip debug symbols to reduce size
BIN_SIZE_BEFORE=$(/usr/bin/stat -f%z "$BIN_SRC")
/usr/bin/strip "$BIN_SRC" 2>/dev/null || true
BIN_SIZE_AFTER=$(/usr/bin/stat -f%z "$BIN_SRC")
echo "  Binary: $(( BIN_SIZE_BEFORE / 1024 )) KB → $(( BIN_SIZE_AFTER / 1024 )) KB"

# ── Step 3: Create app bundle ───────────────────────────────
echo ""
echo "[3/6] Creating app bundle..."

# Clean & create
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BIN_SRC" "$APP_BUNDLE/Contents/MacOS/ClaudeCodePanel"
chmod +x "$APP_BUNDLE/Contents/MacOS/ClaudeCodePanel"

# Copy icon
cp "$BUILD_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Write PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeCodePanel</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudecodepanel.app</string>
    <key>CFBundleName</key>
    <string>Claude Code Panel</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Code Panel</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "  ✓ Bundle created"

# ── Step 4: Code sign ────────────────────────────────────────
echo ""
echo "[4/6] Code signing..."
/usr/bin/codesign --sign - --force --deep "$APP_BUNDLE" 2>&1
echo "  ✓ Signed (ad-hoc)"

# ── Step 5: Verify bundle ────────────────────────────────────
echo ""
echo "[5/6] Verifying bundle..."
echo "  Structure:"
/usr/bin/find "$APP_BUNDLE" -type f | /usr/bin/sed "s|$APP_BUNDLE||" | sort
echo ""
echo "  Binary arch:"
/usr/bin/lipo -info "$APP_BUNDLE/Contents/MacOS/ClaudeCodePanel" 2>/dev/null || /usr/bin/file "$APP_BUNDLE/Contents/MacOS/ClaudeCodePanel"
echo ""
APP_SIZE=$(/usr/bin/du -sk "$APP_BUNDLE" | /usr/bin/awk '{print $1}')
echo "  App size: $(( APP_SIZE )) KB"

# ── Step 6: Create DMG ──────────────────────────────────────
echo ""
echo "[6/6] Creating DMG..."

DMG_TMP="$BUILD_DIR/tmp.dmg"
DMG_OUT="$BUILD_DIR/${DMG_NAME}.dmg"

# Remove old DMGs
rm -f "$DMG_TMP" "$DMG_OUT"

# Detach any lingering mounts
/usr/bin/hdiutil detach "/Volumes/$VOL_NAME" 2>/dev/null || true

# Create read-write DMG
/usr/bin/hdiutil create \
    -volname "$VOL_NAME" \
    -size 10m \
    -layout NONE \
    -fs HFS+ \
    -quiet \
    "$DMG_TMP"

# Mount — parse mount point from hdiutil output (handles spaces in volume names)
HDIUTIL_OUT=$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen "$DMG_TMP" 2>&1)
# Extract the path after "/Volumes/" on the line that contains it
MOUNT_POINT=$(echo "$HDIUTIL_OUT" | /usr/bin/grep -o '/Volumes/.*' | /usr/bin/head -1)
echo "  Mounted at: $MOUNT_POINT"

# Remove stale symlink if present
rm -f "$MOUNT_POINT/Applications" 2>/dev/null || true

# Copy app
rm -rf "$MOUNT_POINT/$APP_NAME" 2>/dev/null || true
cp -R "$APP_BUNDLE" "$MOUNT_POINT/"

# Create Applications symlink
ln -s /Applications "$MOUNT_POINT/Applications"

# Set custom icon for the volume (copy icon to root as .VolumeIcon.icns)
cp "$BUILD_DIR/AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns"
/usr/bin/SetFile -a C "$MOUNT_POINT" 2>/dev/null || true

# Note: Finder icon layout is left at macOS defaults.
# The .DS_Store with custom positions can be added later via
# `create-dmg` or manual layout.

# Detach (force if needed)
/usr/bin/hdiutil detach "$MOUNT_POINT" -force -quiet 2>/dev/null || true

# Convert to compressed read-only
echo "  Compressing..."
/usr/bin/hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" -quiet
rm -f "$DMG_TMP"

DMG_SIZE=$(/usr/bin/stat -f%z "$DMG_OUT")
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ $DMG_NAME.dmg — $(( DMG_SIZE / 1024 )) KB"
echo "  $DMG_OUT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
