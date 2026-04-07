# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude's goal

The goal for Claude is to help develop PicaSim across Windows, Android, macOS and iOS.

The original project has been ported from Marmalade SDK to SDL2 + OpenGL. Windows, Android, macOS and iOS ports are functional.

The original project is owned by me, so I have all rights to do this.

The intention is to not change any existing behaviour significantly.

## Building

Always use CMake presets:

**Windows:**
- Debug: `cmake --build --preset windows-x64-debug`
- Release: `cmake --build --preset windows-x64-release`

**macOS (arm64):**
- Configure: `VCPKG_ROOT=/Users/roberto/vcpkg cmake --preset macos-arm64`
- Debug: `VCPKG_ROOT=/Users/roberto/vcpkg cmake --build --preset macos-arm64-debug`
- Release: `VCPKG_ROOT=/Users/roberto/vcpkg cmake --build --preset macos-arm64-release`
- Run: `cd data && ../build/macos-arm64/Debug/PicaSim` (must run from `data/` directory)

**iOS:**
- Configure: `cmake --preset ios-device`
- Debug: `cmake --build --preset ios-device-debug`
- Deploy via Xcode: `open build/ios-device/PicaSim.xcodeproj`

**Android:**
- `cd android && gradlew.bat assembleDebug`

Always build in debug when building automatically, if just asked to "build". Requests to build in release will always be explicit.

## Git Commits (instruction for Claude/AI)

Never volunteer to commit changes. Only create commits when explicitly requested by the user.

## Project Overview

PicaSim is a cross-platform R/C flight simulator built with C++. It simulates radio-controlled aircraft with realistic physics, multiple aircraft types (40+), and various environments. The project targets Windows, macOS, Android, and iOS.

**Current stack**: SDL2 (window/input), OpenGL/GLES2 (rendering), OpenAL-Soft (audio), GLM (math), Bullet Physics (physics), Dear ImGui (UI).

**Note**: The project was migrated from Marmalade SDK (no longer commercially available) to SDL2 + OpenGL. Most dependencies are built from git submodules in `third_party/`; vcpkg provides only glad and OpenXR on desktop.

## Architecture

### Core Classes

**PicaSim** (`source/PicaSim/PicaSim.h`) - Singleton orchestrator managing the game loop, camera, aeroplanes, and UI overlays. Handles mode transitions (ground/aeroplane/chase/walk) and game status (flying/paused).

**Aeroplane** (`source/PicaSim/Aeroplane.h`) - Container class that intentionally separates graphics and physics:
- `AeroplaneGraphics` - 3D rendering (can exist without physics for networked/animated planes)
- `AeroplanePhysics` - Flight dynamics simulation (can exist without graphics for AI/headless)
- This separation enables AI pilots, network multiplayer, and non-graphical simulations

**Controller hierarchy**:
- `Controller` - Abstract base for all input
- `HumanController` - Player input from touch/joystick
- `AIController*` variants - AI pilots (Glider, Powered, Tug)

**Environment** - Wind simulation, thermals, and terrain interaction

**Challenge** - Race/duration/limbo game modes with gates and scoring

### Framework Layer

`source/Framework/` contains reusable game engine components:
- `Graphics`, `RenderManager` - Rendering pipeline
- `Camera` - Multiple camera modes
- `AudioManager` - 3D positional audio via OpenAL-Soft
- `EntityManager` - Entity lifecycle management
- `ParticleEngine` - Particle effects
- `ShaderManager` - GPU shader handling

`source/Platform/` contains platform abstraction:
- `S3ECompat.h` - Marmalade API compatibility shims (SDL2 implementations)
- `Input.cpp/h` - Unified input handling (keyboard, mouse, touch, gamepad)
- `imgui_impl_sdl2.cpp/h` - ImGui SDL2 backend
- `GLCompat.h` - Apple platform OpenGL header shim (pre-included via CMake `-include` on our targets only)
- `AndroidAssets.cpp/h` - APK asset extraction to internal storage
- `VRManager.cpp/h`, `OpenXRRuntime.cpp/h` - VR support via OpenXR (desktop only)
- `FontRenderer.cpp/h` - Bitmap font rendering for in-game overlay text

### Physics

Uses Bullet Physics (`source/bullet-2.81/`) for rigid body dynamics. Custom aerodynamics code in `AeroplanePhysics.cpp` calculates lift, drag, and control surface effects using aerofoil definitions.

### Data Organization

All data lives in `data/` directory. The application runs with `data/` as the working directory.

**data/SystemData/** - Low-level data representations (read-only, committed):
- `Aeroplanes/` - Aircraft XML definitions + AC3D models (.ac)
- `Aerofoils/` - Airfoil profiles (Symmetric, SemiSymmetric, Reflex)
- `Panoramas/` - Skybox environments with heightmaps
- `Audio/` - Sound effects (22050/44100Hz raw files)

**data/SystemSettings/** - User-facing configuration (read-only, committed):
- `Aeroplane/` - Aircraft selection presets
- `Challenge/` - Race/challenge definitions
- `Controller/` - Input configurations
- `Environment/` - Weather and terrain settings
- `Options/` - Quality presets (Low/Standard/High)

**data/UserData/** - User-created content (gitignored, created at runtime):
- Custom aircraft, scenarios, etc.

**data/UserSettings/** - User preferences (gitignored, created at runtime):
- `settings.xml` - User's saved settings

All configuration uses XML parsed via tinyxml (`source/tinyxml/`).

### Platform Abstractions

- `source/Platform/S3ECompat.h` - Compatibility layer replacing Marmalade s3e* APIs with SDL2
- `source/Platform/Input.cpp` - SDL2-based input (keyboard, mouse, touch, gamepad)

## Platform-Specific Notes

### macOS

- **OpenGL 2.1** with GLSL 1.20 (via Apple's Metal translation layer)
- GLSL 1.20 does **not** support `precision` qualifiers — they are stripped at runtime by `stripPrecisionQualifiers()` in `Shaders.cpp`
- The `GLSL()` macro stringifies shader bodies onto one line; the stripping function does find-and-replace on the whole string, not line-by-line
- Window context: compatibility profile (not core), OpenGL 2.1 requested explicitly
- `GLCompat.h` is pre-included via CMake `-include` flag on Framework/Platform/Heightfield/PicaSim targets (NOT on third-party targets like ImGui/SDL2)
- VR (OpenXR) is disabled on Apple platforms; `VRManager.cpp` and `OpenXRRuntime.cpp` are excluded from build
- `GL_MAX_VERTEX_UNIFORM_VECTORS` and similar GLES2 constants are defined in `GLCompat.h` for macOS

### iOS

- **OpenGL ES 2.0** with GLSL 1.00
- At startup, `Main.cpp` does `chdir(GetBasePath() + "data")` so all relative paths work without per-file resolution
- `std::filesystem` is **not available** on iOS 12 (requires iOS 13+) — use `<dirent.h>` + `<sys/stat.h>` instead
- GLES2 requires `GL_CLAMP_TO_EDGE` for non-power-of-two (NPOT) textures (otherwise they render black)
- UI scaling uses pixel-based formula (`height / 720.0f`), not the Android DPI-aware formula
- SDL2 on iOS uses a non-zero default framebuffer — `FrameBufferObject` saves/restores `GL_FRAMEBUFFER_BINDING`
- CMake uses Xcode generator (`cmake --preset ios-device`); deploy via Xcode project
- Install rules are excluded (`if(NOT ANDROID AND NOT IOS)`)
- iOS bundle resources (data/, icons, LaunchScreen, PrivacyInfo) are configured in CMakeLists.txt

### Bullet Physics (source/bullet-2.81/)

- `btScalar.h` had a `#end` typo (should be `#endif`) and malformed `#else` nesting in the DEBUG assert block — fixed for ARM64/clang
- `ac3d.cpp` guards `<malloc.h>` with `#ifdef _WIN32` (not available on macOS/iOS)

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `windows-build.yml` - Windows x64 build + install
- `macos-build.yml` - macOS arm64 + x86_64 builds, universal binary, DMG creation
- `android-build.yml` - Android debug APK build
- `ios-build.yml` - iOS device build (unsigned IPA)

All workflows trigger on push to `main` and `port/mobile-fixes`, plus `workflow_dispatch`.

## macOS Distribution Scripts

- `macos_create_app_bundle.sh` - Packages the installed build into a .app bundle
- `macos_create_dmg.sh` - Creates a DMG from the .app bundle
- `macos_notarize.sh` - Code signing and notarization for distribution
- `resources/generate_icons.py` - Generates Windows, Android and iOS icons from source images

## Migration Status

All four platform ports (Windows, Android, macOS, iOS) are **functional**.

### Completed

**Windows Desktop**
- CMake with git submodules + vcpkg (glad, OpenXR)
- SDL2 window creation and OpenGL context via glad
- Full rendering pipeline: ShaderManager, FrameBufferObject, skybox, particles
- Math types (GLM replacing CIwFVec3/CIwFMat/etc.)
- VR support via OpenXR

**macOS Desktop**
- CMake preset `macos-arm64` (Ninja Multi-Config, vcpkg for glad)
- OpenGL 2.1 with GLSL 1.20 (precision qualifiers stripped at runtime)
- `GLCompat.h` for OES→core mapping and missing GLES2 constants
- App bundle creation, DMG packaging, notarization scripts

**Android**
- Gradle 8.5 + CMake build, APK packaging with bundled assets
- GLES2 rendering (shader-based, no fixed-function pipeline)
- Asset extraction from APK to internal storage on first launch
- DPI-aware UI scaling, drag-to-scroll, safe area insets
- Supported ABIs: arm64-v8a, x86_64

**iOS**
- CMake preset `ios-device` (Xcode generator, arm64, deployment target 12.0)
- GLES2 rendering with NPOT texture handling
- `chdir` to bundle `data/` directory at startup for path resolution
- `dirent`-based directory scanning (no std::filesystem on iOS 12)
- Pixel-based UI scaling
- App icons, LaunchScreen, PrivacyInfo.xcprivacy in `ios/`

**Audio (OpenAL-Soft)**
- Complete 3D positional audio with distance attenuation
- 32 sound channels with proper source management
- Doppler effect, volume ramping, frequency scaling

**UI (Dear ImGui)**
- All menus migrated from IwUI to ImGui
- SDL2 platform backend (`source/Platform/imgui_impl_sdl2.cpp`)
- Unified style system with font scaling
- Bitmap font renderer for in-game overlay text
- Scrollable tab strips for mobile

**Input (SDL2)**
- Keyboard, mouse/touch, gamepad (SDL2 game controller API)

**Networking (SDL2_net)**
- TCP server on port 7777 for remote aircraft control

## Licensing

PicaSim source is licensed under the **PolyForm Noncommercial License 1.0.0**. Third-party components have separate licenses:
- Bullet Physics: zlib license
- tinyxml: zlib license
- SDL2, SDL2_net: zlib license
- OpenAL-Soft: LGPL
- GLM, imgui: MIT license
- stb: MIT/public domain
- 3D models and images: authorized for PicaSim derivatives only; other uses require permission

## Read
 - README.md
 - CODE_STYLE.md
 - ParallaxPanorama.md
