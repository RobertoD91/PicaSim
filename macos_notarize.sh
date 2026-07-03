#!/bin/bash
# Helper for macOS signing + notarization via CLI.
# - Assumes dist/PicaSim.app exists (single-arch or universal via GitHub Actions).
# - Requires Developer ID certs already created via Xcode; paid account needed.
# - One-time setup: xcrun notarytool store-credentials "picasim-profile"
set -e

# Guard: require Developer ID identity name in env
if [ -z "${PICASIM_MACOS_CERT:-}" ]; then
    echo "This script is for Apple Developer accounts only. Set PICASIM_MACOS_CERT to your 'Developer ID Application: ...' identity and rerun."
    exit 1
fi

# Determine version dynamically
VERSION="1.0.0"
if [ -f "VERSIONS.txt" ]; then
    VERSION=$(grep -oE 'Version [0-9.]+' VERSIONS.txt | head -1 | sed 's/Version //' || echo "1.0.0")
fi
DMG_FILE="dist/PicaSim-${VERSION}.dmg"

# Check certs in keychain; need "Developer ID Application"
security find-identity -v -p codesigning

# Sign .app
codesign --force --deep --options runtime --timestamp --sign "$PICASIM_MACOS_CERT" dist/PicaSim.app

# Verify .app signature
codesign --verify --deep --strict --verbose=2 dist/PicaSim.app

# Create DMG from app
./macos_create_dmg.sh dist/PicaSim.app dist

# Prereq to notarize via CLI: credential profile in keychain (one-time)
# xcrun notarytool store-credentials "picasim-profile"
# Alternatively (used by CI), provide an App Store Connect API key via env:
#   PICASIM_NOTARY_KEY_FILE - path to the AuthKey_XXXX.p8 file
#   PICASIM_NOTARY_KEY_ID   - App Store Connect API key ID
#   PICASIM_NOTARY_ISSUER   - App Store Connect API issuer ID

# Submit DMG for notarization
if [ -n "${PICASIM_NOTARY_KEY_FILE:-}" ] && [ -n "${PICASIM_NOTARY_KEY_ID:-}" ] && [ -n "${PICASIM_NOTARY_ISSUER:-}" ]; then
    xcrun notarytool submit "$DMG_FILE" \
        --key "$PICASIM_NOTARY_KEY_FILE" \
        --key-id "$PICASIM_NOTARY_KEY_ID" \
        --issuer "$PICASIM_NOTARY_ISSUER" \
        --wait
else
    xcrun notarytool submit "$DMG_FILE" --keychain-profile "picasim-profile" --wait
fi

# Staple ticket to DMG
xcrun stapler staple "$DMG_FILE"

# Optionally staple the app for standalone testing
xcrun stapler staple dist/PicaSim.app

# Final Gatekeeper check
spctl --assess --type open --context context:primary-signature --verbose dist/PicaSim.app
