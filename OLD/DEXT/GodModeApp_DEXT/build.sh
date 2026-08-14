#!/bin/bash
set -e

APP_NAME="ANE_App"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

echo "[*] Creating macOS App Bundle..."
mkdir -p "$MACOS_DIR"

# 1. Compile Objective-C++ Wrapper
echo "[*] Compiling C++ Backend Wrapper..."
clang++ -c -std=c++11 -ObjC++ GodModeWrapper.mm -o GodModeWrapper.o -I/System/Library/Frameworks/IOKit.framework/Headers

# 2. Compile ane_bridge directly into our app instead of using dylib
echo "[*] Compiling ANE Bridge..."
clang -c -O2 -fobjc-arc -I../ANE-main/bridge ../ANE-main/bridge/ane_bridge.m -o ane_bridge.o

# 3. Compile Swift Code & Link everything together
echo "[*] Compiling Swift UI and Linking..."
swiftc App.swift ContentView.swift BackendManager.swift \
    -import-objc-header GodModeApp-Bridging-Header.h \
    GodModeWrapper.o ane_bridge.o \
    -lc++ \
    -framework IOKit -framework Foundation -framework SwiftUI -framework AppKit -framework IOSurface \
    -o "$MACOS_DIR/$APP_NAME"

echo "[+] Build Complete: $APP_DIR"




