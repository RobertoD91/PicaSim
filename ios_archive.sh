#!/bin/bash
#
# ios_archive.sh - Create an Xcode archive for TestFlight/App Store upload
#
# CMake's Xcode generator hardcodes CONFIGURATION_BUILD_DIR to an absolute path
# in each target's build settings. This prevents Xcode from redirecting output
# during Archive, so the dSYM is generated but never copied into the .xcarchive.
#
# This script overrides CONFIGURATION_BUILD_DIR on the command line, letting
# Xcode use its standard archive intermediates path, which properly handles
# dSYM copying.
#
# Usage:
#   ./ios_archive.sh              # Archive and open in Xcode Organizer
#   ./ios_archive.sh --export     # Archive and export IPA (requires ExportOptions.plist)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/ios-device"
PROJECT="$BUILD_DIR/PicaSim.xcodeproj"

if [ ! -d "$PROJECT" ]; then
    echo "Error: Xcode project not found at $PROJECT"
    echo "Run 'cmake --preset ios-device' first."
    exit 1
fi

DATE_DIR=$(date +%Y-%m-%d)
DATE_STAMP=$(date +'%d-%m-%Y, %H.%M')
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$DATE_DIR"
ARCHIVE_PATH="$ARCHIVE_DIR/PicaSim $DATE_STAMP.xcarchive"

mkdir -p "$ARCHIVE_DIR"

echo "Archiving PicaSim..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme PicaSim \
    -archivePath "$ARCHIVE_PATH" \
    CONFIGURATION_BUILD_DIR='$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'

# Verify dSYM was included
if [ -d "$ARCHIVE_PATH/dSYMs/PicaSim.app.dSYM" ]; then
    echo "dSYM included in archive."
else
    echo "WARNING: dSYM not found in archive."
fi

echo ""
echo "Archive created: $ARCHIVE_PATH"

if [ "$1" = "--export" ]; then
    EXPORT_OPTIONS="$SCRIPT_DIR/ios/ExportOptions.plist"
    if [ ! -f "$EXPORT_OPTIONS" ]; then
        echo "Error: ExportOptions.plist not found at $EXPORT_OPTIONS"
        exit 1
    fi
    IPA_DIR="$SCRIPT_DIR/build/ios-ipa"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$IPA_DIR"
    echo "IPA exported to: $IPA_DIR"
else
    echo "Opening in Xcode Organizer..."
    open "$ARCHIVE_PATH"
fi
