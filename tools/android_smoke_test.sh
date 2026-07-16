#!/bin/bash
# Smoke test run inside the android-emulator-runner action: install the APK,
# launch the activity and verify the process is still alive shortly after.
# Kept in a script because the action executes its `script:` input line by
# line, which breaks multi-line shell constructs.
set -e

adb install apk/app-phone-debug.apk
adb shell am start -n com.rowlhouse.picasim/.PicaSimActivity

# Poll for up to 60 seconds for the process to appear
for i in $(seq 1 12); do
    sleep 5
    if adb shell ps -A | grep -q com.rowlhouse.picasim; then
        echo "PicaSim is running OK"
        exit 0
    fi
    echo "Waiting for PicaSim... ($((i*5))s)"
done

echo "PicaSim did not start within 60 seconds"
adb logcat -d | grep -E "com.rowlhouse.picasim|SDL|FATAL|AndroidRuntime" | tail -100
exit 1
