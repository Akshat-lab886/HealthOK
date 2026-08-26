#!/bin/bash
# HealthOK toolchain environment — keeps ALL tool state inside the workspace
# (sandbox policy: workspace-write). Source this in every build shell.
export HEALTHOK_ROOT="/Users/akshatpratap/HealthOK"
export FLUTTER_ROOT="$HEALTHOK_ROOT/.tooling/flutter"
export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_CACHE="$HEALTHOK_ROOT/.tooling/pub-cache"
export GRADLE_USER_HOME="$HEALTHOK_ROOT/.tooling/gradle-home"
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export NO_FLUTTER_ANALYTICS=true
export CI=true
