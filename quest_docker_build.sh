#!/bin/bash
# quest_docker_build.sh - build the Quest (or any Android) APK locally in
# Docker, much faster than a CI round-trip.
#
# Usage:
#   ./quest_docker_build.sh                      # assembleQuestDebug
#   ./quest_docker_build.sh assemblePhoneDebug   # any gradle task(s)
#   ./quest_docker_build.sh --rebuild-image      # force-rebuild the image first
#
# Caching for fast incremental builds:
#   - gradle caches live in the named volume 'picasim-gradle'
#   - native build outputs (android/app/.cxx, app/build) live in the repo
#     bind-mount, so they persist on the host between runs
#
# The image runs as linux/amd64 because the Android NDK has no linux/arm64
# host toolchain. On Apple Silicon enable "Use Rosetta for x86_64/amd64
# emulation" in Docker Desktop settings, or the build will be very slow.
set -e

cd "$(dirname "$0")"

IMAGE=picasim-android-build
GRADLE_VOLUME=picasim-gradle

if [ "$1" = "--rebuild-image" ]; then
    shift
    docker build --platform linux/amd64 -t "$IMAGE" -f docker/android-build.Dockerfile docker
elif ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Building the $IMAGE image (one-time)..."
    docker build --platform linux/amd64 -t "$IMAGE" -f docker/android-build.Dockerfile docker
fi

# Persistent local debug signing key (gitignored, NOT committed): generated
# once so every local build - docker or native - shares the same signature
# and installs over the previous one.
if [ ! -f android/debug.keystore ]; then
    echo "Generating local debug keystore (one-time)..."
    docker run --rm --platform linux/amd64 -v "$PWD:/src" -w /src "$IMAGE" \
        keytool -genkeypair -keystore android/debug.keystore \
        -storepass android -alias androiddebugkey -keypass android \
        -keyalg RSA -keysize 2048 -validity 10950 \
        -dname "CN=Android Debug,O=Android,C=US"
fi

# android/local.properties on the host (if any) points to the host SDK path;
# shadow it inside the container with the container's SDK location.
LOCAL_PROPS_OVERRIDE=$(mktemp)
echo "sdk.dir=/opt/android-sdk" > "$LOCAL_PROPS_OVERRIDE"
trap 'rm -f "$LOCAL_PROPS_OVERRIDE"' EXIT

TASKS=("$@")
[ ${#TASKS[@]} -eq 0 ] && TASKS=(assembleQuestDebug)

docker run --rm --platform linux/amd64 \
    -v "$PWD:/src" \
    -v "$GRADLE_VOLUME:/root/.gradle" \
    -v "$LOCAL_PROPS_OVERRIDE:/src/android/local.properties" \
    -w /src/android \
    "$IMAGE" ./gradlew "${TASKS[@]}"

APK=android/app/build/outputs/apk/quest/debug/app-quest-debug.apk
if [ -f "$APK" ]; then
    echo ""
    echo "APK: $APK"
    echo "Install and run on the headset with:  ./quest_run.sh $APK"
fi
