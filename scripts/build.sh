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
swift build -c release --arch arm64 --disable-sandbox 2>&1 | tail -3

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

# ── Step 6: Package ──────────────────────────────────────
echo ""
echo "[6/6] Packaging..."

DMG_OUT="$BUILD_DIR/${DMG_NAME}.dmg"
rm -f "$DMG_OUT" "$BUILD_DIR/${DMG_NAME}.zip"

# Try hdiutil, fall back to zip if sandboxed
if /usr/bin/hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -size 20m \
    "$DMG_OUT" 2>/dev/null; then
    DMG_SIZE=$(/usr/bin/stat -f%z "$DMG_OUT")
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✓ $DMG_NAME.dmg — $(( DMG_SIZE / 1024 )) KB"
    echo "  $DMG_OUT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    # Sandbox prevents DMG creation — create zip as fallback
    echo "  ⚠ hdiutil restricted by sandbox — creating zip + DMG script"
    cd "$BUILD_DIR"
    /usr/bin/zip -r "${DMG_NAME}.zip" "$APP_NAME.app" -q
    ZIP_SIZE=$(/usr/bin/stat -f%z "${DMG_NAME}.zip")
    
    # Also write a helper script for the user to create the DMG
    cat > "$BUILD_DIR/make_dmg.sh" << 'DMGSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"
echo "Creating DMG..."
hdiutil create -volname "Claude Code Panel" \
    -srcfolder "Claude Code Panel.app" \
    -format UDZO -imagekey zlib-level=9 \
    "ClaudeCodePanel-1.8.dmg"
echo "Done: $(pwd)/ClaudeCodePanel-1.8.dmg"
open -R ClaudeCodePanel-1.8.dmg
DMGSCRIPT
    chmod +x "$BUILD_DIR/make_dmg.sh"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✓ ${DMG_NAME}.zip — $(( ZIP_SIZE / 1024 )) KB"
    echo "  $BUILD_DIR/${DMG_NAME}.zip"
    echo ""
    echo "  Create DMG: bash $BUILD_DIR/make_dmg.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
