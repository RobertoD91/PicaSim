# PicaSim on Meta Quest

The `quest` Gradle product flavor builds the Android app for Meta Quest
headsets (Quest 2 / Quest Pro / Quest 3) with OpenXR VR support enabled.
The regular Android build is the `phone` flavor and is unchanged.

## What the quest flavor does

- Passes `-DPICASIM_QUEST=ON` to CMake, which enables `PICASIM_ENABLE_VR`,
  defines `PICASIM_VR_SUPPORT=1` and `PICASIM_QUEST=1`, and links the OpenXR
  loader and `GLESv3` in addition to `GLESv2`.
- Pulls the Khronos OpenXR loader from Maven Central
  (`org.khronos.openxr:openxr_loader_for_android:1.1.49`), exposed to the
  CMake build via Gradle's prefab support (`find_package(OpenXR CONFIG)`).
- Merges a Quest manifest overlay (`android/app/src/quest/AndroidManifest.xml`):
  head-tracking feature requirement, `com.oculus.intent.category.VR` launcher
  category, `com.oculus.supportedDevices` metadata, and removal of the
  phone-oriented `screenOrientation` lock.
- Uses the same application id as the phone flavor
  (`com.rowlhouse.picasim`), so only one of the two can be installed on a
  device at a time.

## Building

```sh
cd android
./gradlew assembleQuestDebug     # -> app/build/outputs/apk/quest/debug/app-quest-debug.apk
./gradlew assemblePhoneDebug     # regular phone build
```

CI (`.github/workflows/android-build.yml`) builds both flavors and uploads
the quest APK as the `picasim-quest-debug` artifact.

## Installing (sideload)

1. Enable developer mode on the headset (requires a Meta developer account:
   pair the headset with the Meta Horizon phone app, then toggle Developer
   Mode) and connect via USB-C.
2. Install with adb:

   ```sh
   adb install android/app/build/outputs/apk/quest/debug/app-quest-debug.apk
   ```

3. Launch from **Library → Unknown Sources** on the headset.

### Fast local builds with Docker

CI round-trips are slow for iteration; `./quest_docker_build.sh` builds the
APK locally in a container (image built once from
`docker/android-build.Dockerfile`, with JDK + Android SDK/NDK). Gradle caches
persist in the `picasim-gradle` named volume and native build outputs live in
the repo bind-mount, so incremental builds are fast. Any gradle task can be
passed as argument (default `assembleQuestDebug`); `--rebuild-image` forces
an image rebuild. On Apple Silicon enable "Use Rosetta for x86_64/amd64
emulation" in Docker Desktop (the NDK has no linux/arm64 host toolchain).
Typical loop:

```sh
./quest_docker_build.sh && ./quest_run.sh android/app/build/outputs/apk/quest/debug/app-quest-debug.apk
```

### One-step install + launch + logs

`./quest_run.sh [path/to.apk]` (repo root) installs the APK if given,
(re)launches the app via adb (USB or WiFi) and streams the app's logcat
filtered by PID — dropping all the Quest system noise while keeping PicaSim
traces, SDL and OpenXR loader/runtime output. The stream is also saved to
`picasim_quest_run.log`, and on Ctrl-C it appends any native crash report.
CI names the quest APK `com.rowlhouse.picasim-quest-v<version>-b<build>.apk`
so sideloaded builds are identifiable.

### Signing

The goal is a *stable* debug signature, so successive builds install over
each other instead of failing with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
No keystore is committed to the repo. In order of preference:

1. **Your own key via secrets** (CI): set `ANDROID_KEYSTORE_BASE64` (the
   keystore file, base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`
   and `ANDROID_KEY_PASSWORD`.
2. **Generated keystore** (fallback): CI generates `android/debug.keystore`
   on first run and persists it in the Actions cache under the key
   `android-debug-keystore-v1`; locally `quest_docker_build.sh` generates the
   same (gitignored) file once. Note the Actions cache evicts entries unused
   for 7 days — if that happens a new key is generated and the next
   `adb install` hits a one-time signature mismatch, which `quest_run.sh`
   handles by uninstalling and retrying.

## Startup defaults

The quest flavor forces a set of startup defaults so the app is usable
without menus: skip menus (free fly), powered trainer (Jackdaw) in the 3D
recreation ground, Xbox joystick profile, start unpaused. They can be turned
off at runtime, without rebuilding, via an Android system property:

```sh
adb shell setprop debug.picasim.questdefaults 0   # vanilla behavior
adb shell setprop debug.picasim.questdefaults 1   # defaults on (default)
```

Forcing VR on is not gated: without it the app renders to the invisible SDL
surface and never leaves the system loading screen.

## Input

There is no VR (Touch) controller support. Fly with an RC transmitter
connected over USB-C or Bluetooth — it shows up as a standard SDL gamepad,
just like on phones. A Bluetooth mouse works for navigating the menus.

## Status / known gaps

- **Experimental** — the build-system support is in place, but the rendering
  path is still being ported to GLES3 for the Quest's OpenXR runtime.
- Not yet tested on real hardware.
- No hand tracking, no Touch controller bindings, no Quest-specific UI
  (menus render on the 2D layer).
