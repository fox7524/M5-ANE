#!/bin/bash
set -e

APP_NAME="M5 Ultimate"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "[*] Creating macOS App Bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy payload assets to Resources to make the app standalone
echo "[*] Copying assets to Resources..."
cp ../payloads/run_benchmark.sh "$RESOURCES_DIR/"
cp ../payloads/patch_ollama.sh "$RESOURCES_DIR/"
# Copy payload binaries into the App bundle
echo "Embedding payloads..."
mkdir -p "$APP_DIR/Contents/Resources/payloads/llama"
mkdir -p "$APP_DIR/Contents/Resources/payloads/mlx"

# Create Entitlements XML for signing
cat << 'EOF' > build/m5_ents.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
EOF

cp -f ../llama.cpp/build/bin/llama-server "$APP_DIR/Contents/Resources/payloads/llama/llama-server.ane" 2>/dev/null || true
cp -f ../llama.cpp/build/bin/lib*.dylib "$APP_DIR/Contents/Resources/payloads/llama/" 2>/dev/null || true
cp -f ../llama.cpp/ggml/src/ggml-metal/ggml-metal.metal "$APP_DIR/Contents/Resources/payloads/llama/" 2>/dev/null || true
cp -f ../mlx/python/mlx/lib/mlx.metallib "$APP_DIR/Contents/Resources/payloads/mlx/" 2>/dev/null || true
cp -f ../mlx/python/mlx/lib/libmlx.dylib "$APP_DIR/Contents/Resources/payloads/mlx/" 2>/dev/null || true

# Inject libmetal_interceptor into llama-server.ane and libmlx.dylib
cp ../payloads/libmetal_interceptor.dylib "$APP_DIR/Contents/Resources/payloads/llama/" 2>/dev/null || true
cp ../payloads/libmetal_interceptor.dylib "$APP_DIR/Contents/Resources/payloads/mlx/" 2>/dev/null || true
cp ../payloads/insert_dylib "$RESOURCES_DIR/" 2>/dev/null || true
chmod +x "$RESOURCES_DIR/insert_dylib"

if [ -f "$APP_DIR/Contents/Resources/payloads/llama/llama-server.ane" ]; then
    "$RESOURCES_DIR/insert_dylib" --all-yes "@executable_path/libmetal_interceptor.dylib" "$APP_DIR/Contents/Resources/payloads/llama/llama-server.ane"
    mv "$APP_DIR/Contents/Resources/payloads/llama/llama-server.ane_patched" "$APP_DIR/Contents/Resources/payloads/llama/llama-server.ane"
fi

if [ -f "$APP_DIR/Contents/Resources/payloads/mlx/libmlx.dylib" ]; then
    "$RESOURCES_DIR/insert_dylib" --all-yes "@loader_path/libmetal_interceptor.dylib" "$APP_DIR/Contents/Resources/payloads/mlx/libmlx.dylib"
    mv "$APP_DIR/Contents/Resources/payloads/mlx/libmlx.dylib_patched" "$APP_DIR/Contents/Resources/payloads/mlx/libmlx.dylib"
fi

# Copy injection script
cp -f crack_lmstudio.js "$APP_DIR/Contents/Resources/"
cp ../payloads/gpu_stress_tester "$RESOURCES_DIR/" 2>/dev/null || true
cp ../payloads/ane_stress_tester "$RESOURCES_DIR/" 2>/dev/null || true
cp ../payloads/libmetal_interceptor.dylib "$RESOURCES_DIR/" 2>/dev/null || true
cp AppIcon.icns "$RESOURCES_DIR/"
chmod +x "$RESOURCES_DIR"/*.sh
chmod +x "$RESOURCES_DIR"/*_tester 2>/dev/null || true
chmod +x "$RESOURCES_DIR"/insert_dylib 2>/dev/null || true

# Create Info.plist (Removed LSUIElement so it shows in Dock)
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.fox.m5ultimate</string>
    <key>CFBundleName</key>
    <string>M5 Ultimate</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 1. Compile Objective-C++ Wrapper
echo "[*] Compiling C++ Backend Wrapper..."
clang++ -c -std=c++11 -ObjC++ M5UltimateWrapper.mm -o M5UltimateWrapper.o -I/System/Library/Frameworks/IOKit.framework/Headers

# 2. Compile ane_bridge directly into our app instead of using dylib
echo "[*] Compiling ANE Bridge..."
clang -c -O2 -fobjc-arc -I../ANE-main/bridge ../ANE-main/bridge/ane_bridge.m -o ane_bridge.o

# 3. Compile Swift Code & Link everything together
echo "[*] Compiling Swift UI and Linking..."
swiftc App.swift ContentView.swift BackendManager.swift \
    -import-objc-header M5Ultimate-Bridging-Header.h \
    M5UltimateWrapper.o ane_bridge.o \
    -lc++ \
    -framework IOKit -framework Foundation -framework SwiftUI -framework AppKit -framework IOSurface \
    -o "$MACOS_DIR/$APP_NAME"

echo "[*] Signing the App Bundle with entitlements..."
xattr -cr "$APP_DIR"
codesign --force --deep --sign - --entitlements build/m5_ents.xml "$APP_DIR"

echo "[+] Build Complete: $APP_DIR"
