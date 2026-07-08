# Local Android/Quest build environment for fast iteration without CI.
# Build the image once, then run gradle builds with the repo bind-mounted and
# the gradle cache in a named volume (see quest_docker_build.sh).
#
# NOTE: the Android NDK only ships linux x86_64 host prebuilts, so on Apple
# Silicon this image must run with --platform linux/amd64 (enable
# "Use Rosetta for x86/amd64 emulation" in Docker Desktop for decent speed).
FROM eclipse-temurin:17-jdk-jammy

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python-is-python3 \
        wget unzip zip ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Android command-line tools
ARG CMDLINE_TOOLS=11076708
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS}_latest.zip" -O /tmp/clt.zip \
    && unzip -q /tmp/clt.zip -d /tmp/clt \
    && mv /tmp/clt/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm -rf /tmp/clt /tmp/clt.zip

# SDK components. NDK 27.0.12077973 is what the Android Gradle Plugin actually
# resolves to on CI; cmake satisfies the "3.22.1+" requirement in build.gradle.
# Licenses are accepted so AGP can auto-install anything else it needs.
RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager "platform-tools" \
                  "platforms;android-35" \
                  "build-tools;35.0.0" \
                  "ndk;27.0.12077973" \
                  "cmake;3.22.1"

WORKDIR /src/android
CMD ["./gradlew", "assembleQuestDebug"]
