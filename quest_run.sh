#!/bin/bash
# quest_run.sh - install, launch and capture filtered logs of the Quest build
# over adb (USB or WiFi).
#
# Usage:
#   ./quest_run.sh                          # (re)launch the installed app and stream logs
#   ./quest_run.sh path/to/app-quest.apk    # install first, then launch and stream logs
#   ./quest_run.sh -u path/to/app-quest.apk # uninstall the old app first (clean install)
#   ./quest_run.sh -u                       # just uninstall and exit
#
# Logs are filtered by the app's PID, which drops all the Quest system noise
# (VrShell, tooltips, ...) while keeping everything from the app process:
# PicaSim traces, SDL, the OpenXR loader and the in-process runtime client.
# The stream is also saved to picasim_quest_run.log. Ctrl-C to stop.
set -e

PKG=com.rowlhouse.picasim
ACTIVITY=.PicaSimActivity
LOG_FILE=picasim_quest_run.log

UNINSTALL=0
APK=""
while [ $# -gt 0 ]; do
    case "$1" in
        -u|--uninstall) UNINSTALL=1 ;;
        -*) echo "Unknown option $1"; grep '^#   ' "$0"; exit 1 ;;
        *) APK="$1" ;;
    esac
    shift
done

if ! adb get-state > /dev/null 2>&1; then
    echo "No adb device connected (for WiFi: adb connect <ip>:5555)"
    exit 1
fi

if [ "$UNINSTALL" = 1 ]; then
    echo "Uninstalling $PKG (app data is lost)..."
    adb uninstall "$PKG" || echo "(was not installed)"
    if [ -z "$APK" ]; then
        exit 0
    fi
fi

if [ -n "$APK" ]; then
    echo "Installing $APK..."
    # -r replace, -d allow downgrade (local builds have a lower versionCode
    # than CI builds). If the installed APK was signed with a different debug
    # key (pre stable-keystore builds), uninstall and retry.
    if ! OUT=$(adb install -r -d "$APK" 2>&1); then
        echo "$OUT"
        if echo "$OUT" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
            echo "Signature mismatch - uninstalling $PKG and retrying (app data is lost)..."
            adb uninstall "$PKG" || true
            adb install "$APK"
        else
            exit 1
        fi
    fi
fi

echo "Restarting $PKG..."
adb shell am force-stop "$PKG"
adb logcat -c
adb shell am start -n "$PKG/$ACTIVITY" > /dev/null

# Wait for the process to appear
PID=""
for _ in $(seq 1 20); do
    PID=$(adb shell pidof -s "$PKG" | tr -d '\r')
    [ -n "$PID" ] && break
    sleep 0.5
done

if [ -z "$PID" ]; then
    echo "App process did not start. System-side crash log:"
    adb logcat -d -v time | grep -E "FATAL|AndroidRuntime|DEBUG" | tail -50
    exit 1
fi

echo "App running with PID $PID - streaming logs to $LOG_FILE (Ctrl-C to stop)"
# On Ctrl-C, append any crash report lines (crash_dump runs in another
# process, so the PID filter would miss a native crash backtrace).
trap 'echo; echo "--- crash check ---"; adb logcat -d -v time | grep -E "FATAL|AndroidRuntime|DEBUG   " | tail -40 | tee -a "$LOG_FILE"; exit 0' INT

adb logcat -v time --pid="$PID" | tee "$LOG_FILE"
