#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_NAME="Claude Code Panel"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
VERSION=$(python3 -c "import json; print(json.load(open('$ROOT/version.json'))['version'])" 2>/dev/null || echo "1.9")
DMG_NAME="ClaudeCodePanel-${VERSION}"
VOL_NAME="ClaudeCodePanel-${VERSION}-$$"

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
echo "[6/6] Packaging DMG..."

DMG_OUT="$BUILD_DIR/${DMG_NAME}.dmg"
rm -f "$DMG_OUT" "$BUILD_DIR/${DMG_NAME}.zip"

# Generate DMG background
echo "  Generating DMG background..."
python3 "$ROOT/scripts/generate_icon.py" --dmg-bg
DMG_BG="$BUILD_DIR/dmg_background.png"

# Try hdiutil, fall back to zip if sandboxed
if /usr/bin/hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -size 20m \
    "$DMG_OUT" 2>/dev/null; then

    # Apply layout: re-create as read-write, set up, then convert back
    echo "  Setting up DMG layout..."
    STAGE_DIR="$BUILD_DIR/dmg_stage"
    rm -rf "$STAGE_DIR"
    mkdir -p "$STAGE_DIR"
    cp -R "$APP_BUNDLE" "$STAGE_DIR/"
    ln -s /Applications "$STAGE_DIR/Applications"
    mkdir -p "$STAGE_DIR/.background"
    cp "$DMG_BG" "$STAGE_DIR/.background/background.png"

    # Create read-write DMG from staging
    DMG_RW="$BUILD_DIR/${DMG_NAME}_rw.dmg"
    rm -f "$DMG_RW"
    if /usr/bin/hdiutil create \
        -volname "$VOL_NAME" \
        -srcfolder "$STAGE_DIR" \
        -format UDRW \
        -size 40m \
        "$DMG_RW" 2>/dev/null; then

        # Mount the read-write DMG
        DMG_MOUNT=$(/usr/bin/hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen 2>/dev/null | /usr/bin/grep "/Volumes/" | /usr/bin/awk '{print $NF}')
        if [ -n "$DMG_MOUNT" ] && [ -d "$DMG_MOUNT" ]; then
            # Apply Finder layout
            AS_OUTPUT=$(/usr/bin/osascript 2>&1 << APPLESCRIPT || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 800, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {150, 170}
        set position of item "Applications" of container window to {450, 170}
        close
        open
    end tell
end tell
APPLESCRIPT
)
            if [ -n "$AS_OUTPUT" ]; then
                echo "  ⚠ Finder layout: $(echo "$AS_OUTPUT" | head -1)"
            else
                echo "  ✓ Finder layout applied"
            fi

            /usr/bin/hdiutil detach "$DMG_MOUNT" -force 2>/dev/null || true
        fi

        # Convert to compressed UDZO
        rm -f "$DMG_OUT"
        /usr/bin/hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" 2>/dev/null
        rm -f "$DMG_RW"
    fi

    rm -rf "$STAGE_DIR"

    DMG_SIZE=$(/usr/bin/stat -f%z "$DMG_OUT" 2>/dev/null || echo "0")
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
STAGE="/tmp/claudecodepanel-dmg-$$"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "Claude Code Panel.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Copy background
mkdir -p "$STAGE/.background"
cp dmg_background.png "$STAGE/.background/background.png" 2>/dev/null || true

echo "Creating DMG..."
hdiutil create -volname "Claude Code Panel" \
    -srcfolder "$STAGE" \
    -format UDZO -imagekey zlib-level=9 \
    "ClaudeCodePanel-1.8.dmg"
rm -rf "$STAGE"

# Mount & layout
DMG_MOUNT=$(hdiutil attach "ClaudeCodePanel-1.8.dmg" -readwrite -noverify -noautoopen 2>/dev/null | grep "/Volumes/" | awk '{print $NF}')
if [ -n "$DMG_MOUNT" ] && [ -d "$DMG_MOUNT" ]; then
    osascript << 'AS' 2>/dev/null || true
tell application "Finder"
    tell disk "Claude Code Panel"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 800, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "Claude Code Panel.app" of container window to {150, 170}
        set position of item "Applications" of container window to {450, 170}
        close
        open
    end tell
end tell
AS
    hdiutil detach "$DMG_MOUNT" -force 2>/dev/null || true
    hdiutil convert "ClaudeCodePanel-1.8.dmg" -format UDZO -imagekey zlib-level=9 -o "tmp.dmg" 2>/dev/null
    if [ -f "tmp.dmg" ]; then
        mv "tmp.dmg" "ClaudeCodePanel-1.8.dmg"
    fi
fi
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

# ── Notarization hint ──────────────────────────────────────
echo ""
echo "  Notarize (optional): bash scripts/notarize.sh \"$DMG_OUT\""
echo "  See scripts/notarize.sh for credential setup."
