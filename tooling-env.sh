#!/bin/bash
# HealthOK toolchain environment — keeps ALL tool state inside the workspace
# (sandbox policy: workspace-write). Source this in every build shell.
export HEALTHOK_ROOT="/Users/akshatpratap/HealthOK"
export REAL_HOME="/Users/akshatpratap"
export ANDROID_NDK_HOME="$HEALTHOK_ROOT/.tooling/android-ndk-r28c"
export FLUTTER_ROOT="$HEALTHOK_ROOT/.tooling/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_CACHE="$HEALTHOK_ROOT/.tooling/pub-cache"
export GRADLE_USER_HOME="$HEALTHOK_ROOT/.tooling/gradle-home"
export ANDROID_SDK_ROOT="$HEALTHOK_ROOT/.tooling/android-sdk"
export ANDROID_SDK_HOME="$HEALTHOK_ROOT/.tooling/home"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export NO_FLUTTER_ANALYTICS=true
export CI=true
# Fake HOME keeps every tool's dotfiles (.dart-tool, .config/flutter, .android)
# inside the workspace — required by the sandbox's workspace-write policy.
export HOME="$HEALTHOK_ROOT/.tooling/home"
mkdir -p "$HOME"
