#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code Panel — Notarization Script
#
# Submits the DMG (or .app) to Apple's notary service and staples the ticket.
#
# Prerequisites (choose one):
#   A) App Store Connect API Key (recommended):
#        export APPLE_API_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
#        export APPLE_API_KEY_ID="XXXXXXXXXX"
#        export APPLE_API_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#
#   B) Apple ID + app-specific password:
#        export APPLE_ID="your@email.com"
#        export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#        (or use keychain: security find-generic-password -s "AC_PASSWORD" -w)
#
# Usage:
#   bash scripts/notarize.sh [path-to-dmg-or-app]
# ============================================================================

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
VERSION="${VERSION:-1.8}"
DMG_NAME="ClaudeCodePanel-${VERSION}"
BUNDLE_ID="com.claudecodepanel.app"

# ── Resolve target ─────────────────────────────────────────────────────────

TARGET="${1:-$BUILD_DIR/${DMG_NAME}.dmg}"

if [[ ! -f "$TARGET" ]] && [[ ! -d "$TARGET" ]]; then
    echo "✗ Target not found: $TARGET"
    echo "  Usage: bash scripts/notarize.sh [path-to-dmg-or-app]"
    echo "  Build first: bash scripts/build.sh"
    exit 1
fi

TARGET_NAME="$(basename "$TARGET")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Notarize: $TARGET_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Detect credential method ────────────────────────────────────────────────

NOTARY_CREDS=()
if [[ -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" ]]; then
    echo "  Using: App Store Connect API Key"
    NOTARY_CREDS=(
        --key "$APPLE_API_KEY_PATH"
        --key-id "$APPLE_API_KEY_ID"
        --issuer "$APPLE_API_ISSUER"
    )
elif [[ -n "${APPLE_ID:-}" ]]; then
    echo "  Using: Apple ID ($APPLE_ID)"

    if [[ -n "${APPLE_APP_PASSWORD:-}" ]]; then
        NOTARY_CREDS=(
            --apple-id "$APPLE_ID"
            --password "$APPLE_APP_PASSWORD"
            --team-id "${APPLE_TEAM_ID:-}"
        )
    else
        # Try keychain
        NOTARY_CREDS=(
            --apple-id "$APPLE_ID"
            --password "@keychain:AC_PASSWORD"
            --team-id "${APPLE_TEAM_ID:-}"
        )
    fi
    echo "  (set APPLE_APP_PASSWORD or store in keychain as 'AC_PASSWORD')"
else
    echo ""
    echo "✗ No notarization credentials found."
    echo ""
    echo "  Option A — App Store Connect API Key (recommended):"
    echo "    export APPLE_API_KEY_PATH=\"\$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8\""
    echo "    export APPLE_API_KEY_ID=\"XXXXXXXXXX\""
    echo "    export APPLE_API_ISSUER=\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\""
    echo ""
    echo "  Option B — Apple ID + app-specific password:"
    echo "    export APPLE_ID=\"your@email.com\""
    echo "    export APPLE_APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    echo "    export APPLE_TEAM_ID=\"XXXXXXXXXX\"  # optional"
    echo ""
    echo "  Get an app-specific password: https://appleid.apple.com/account/manage"
    exit 1
fi

# ── Code sign (if not already done) ─────────────────────────────────────────

# Ensure the .app is ad-hoc signed before notarizing the DMG
if [[ "$TARGET" == *.dmg ]]; then
    APP_PATH=$(/usr/bin/mdfind "kMDItemFSName == 'Claude Code Panel.app'" 2>/dev/null | head -1 || echo "")
    if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
        APP_PATH="$BUILD_DIR/Claude Code Panel.app"
    fi
    if [[ -d "$APP_PATH" ]]; then
        echo "  Signing .app (hardened runtime)..."
        /usr/bin/codesign --sign - --force --options runtime --deep "$APP_PATH" 2>&1 || true
    fi
else
    echo "  Signing .app (hardened runtime)..."
    /usr/bin/codesign --sign - --force --options runtime --deep "$TARGET" 2>&1 || true
fi

# ── Submit for notarization ─────────────────────────────────────────────────

echo ""
echo "  Submitting to Apple notary service..."
echo "  (this may take 1-5 minutes)"

SUBMIT_OUTPUT=$(/usr/bin/xcrun notarytool submit "$TARGET" \
    "${NOTARY_CREDS[@]}" \
    --wait \
    --output-format json 2>&1) || true

SUBMIT_ID=$(echo "$SUBMIT_OUTPUT" | /usr/bin/python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
STATUS=$(echo "$SUBMIT_OUTPUT" | /usr/bin/python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','Unknown'))" 2>/dev/null || echo "Unknown")

echo "  Submission ID: $SUBMIT_ID"
echo "  Status: $STATUS"

if [[ "$STATUS" != "Accepted" ]]; then
    echo ""
    echo "  ✗ Notarization failed or returned unexpected status."

    # Try to get detailed log
    if [[ -n "$SUBMIT_ID" ]]; then
        echo ""
        echo "  Fetching detailed log..."
        /usr/bin/xcrun notarytool log "$SUBMIT_ID" "${NOTARY_CREDS[@]}" 2>&1 || true
    fi

    echo ""
    echo "  Raw response:"
    echo "$SUBMIT_OUTPUT" | /usr/bin/python3 -m json.tool 2>/dev/null || echo "$SUBMIT_OUTPUT"
    exit 1
fi

# ── Staple ticket ───────────────────────────────────────────────────────────

echo ""
echo "  Stapling notarization ticket..."

if [[ "$TARGET" == *.dmg ]]; then
    /usr/bin/xcrun stapler staple "$TARGET" 2>&1
else
    /usr/bin/xcrun stapler staple "$TARGET" 2>&1
fi

if /usr/bin/xcrun stapler validate "$TARGET" 2>&1 | /usr/bin/grep -q "worked"; then
    echo "  ✓ Notarization stapled successfully"
else
    echo "  ⚠ Stapling verification unclear — check manually:"
    echo "    spctl -a -vvv -t install \"$TARGET\""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ $TARGET_NAME — Notarized & Stapled"
echo "  Verify: spctl -a -vvv -t install \"$TARGET\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
