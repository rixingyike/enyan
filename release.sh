#!/bin/bash
set -e

APP_NAME="大字有声圣经"
OUTPUT_DIR="build/release"

echo "🚀 Starting Release Build Process..."
echo "📂 Cleaning output directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ==============================================================================
# Android Build
# ==============================================================================
echo "----------------------------------------------------------------"
echo "🤖 Building Android Release (Split per ABI)..."
echo "----------------------------------------------------------------"
# Using --split-per-abi to generate separate APKs for each architecture
flutter build apk --release --split-per-abi

echo "📦 Moving Android APKs..."
# Copy and rename for clarity
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$OUTPUT_DIR/enyan-android-arm64.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$OUTPUT_DIR/enyan-android-armv7.apk"
cp build/app/outputs/flutter-apk/app-x86_64-release.apk "$OUTPUT_DIR/enyan-android-x64.apk"

# ==============================================================================
# macOS Build
# ==============================================================================
echo "----------------------------------------------------------------"
echo "🖥️ Building macOS Release (Universal)..."
echo "----------------------------------------------------------------"
flutter build macos --release

SRC_APP="build/macos/Build/Products/Release/$APP_NAME.app"
EXEC_PATH="Contents/MacOS/$APP_NAME"

if [ -d "$SRC_APP" ]; then
    echo "🔨 Processing macOS Architectures..."
    
    # Universal (Backup/Standard)
    echo "   -> Creating Universal build..."
    cp -R "$SRC_APP" "$OUTPUT_DIR/enyan-macos-universal.app"

    # Function to thin all binaries in an app bundle
    thin_app() {
        local app_path="$1"
        local arch="$2"
        
        echo "   -> Thinning $app_path to $arch..."
        find "$app_path" -type f | while read -r file; do
            # Check if file is a Mach-O binary
            if file "$file" | grep -q "Mach-O"; then
                # Check if it contains the target architecture
                if lipo -info "$file" | grep -q "$arch"; then
                    echo "      Thinning: $(basename "$file")"
                    # Thin the binary (ignore errors if it's already thin or fails)
                    lipo -thin "$arch" "$file" -output "$file.thin" && mv "$file.thin" "$file" || true
                fi
            fi
        done
        
        # Resign everything deep
        codesign --force --sign - --deep "$app_path"
    }

    # Apple Silicon (arm64)
    echo "   -> Creating Apple Silicon (arm64) build..."
    ARM_APP="$OUTPUT_DIR/enyan-macos-arm64.app"
    cp -R "$SRC_APP" "$ARM_APP"
    thin_app "$ARM_APP" "arm64"

    # Intel (x86_64)
    echo "   -> Creating Intel (x86_64) build..."
    INTEL_APP="$OUTPUT_DIR/enyan-macos-x64.app"
    cp -R "$SRC_APP" "$INTEL_APP"
    thin_app "$INTEL_APP" "x86_64"
else
    echo "⚠️ macOS build failed or App not found at expected path: $SRC_APP"
fi

# ==============================================================================
# iOS Build (Currently problematic)
# ==============================================================================
# echo "----------------------------------------------------------------"
# echo "🍎 Building iOS Release..."
# echo "----------------------------------------------------------------"
# flutter build ios --release
# cp -R build/ios/archive/Runner.xcarchive "$OUTPUT_DIR/enyan-ios.xcarchive"


echo "----------------------------------------------------------------"
echo "✅ Release Build Complete."
echo "📂 Artifacts Location: $OUTPUT_DIR"
echo "----------------------------------------------------------------"

echo "📱 Android Artifacts:"
echo "   • enyan-android-arm64.apk"
echo "     - 适用: 主流现代安卓手机 (如 Redmi Note 15, Pixel, Galaxy 等)"
echo "     - 架构: arm64-v8a"
echo ""
echo "   • enyan-android-armv7.apk"
echo "     - 适用: 老旧安卓手机 (Android 5.0 以下)"
echo "     - 架构: armeabi-v7a"
echo ""
echo "   • enyan-android-x64.apk"
echo "     - 适用: 电脑模拟器 / Chromebook"
echo "     - 架构: x86_64"

echo "----------------------------------------------------------------"
echo "🖥️ macOS Artifacts:"
echo "   • enyan-macos-arm64.app"
echo "     - 适用: Apple Silicon 芯片 Mac (M1, M2, M3...)"
echo "     - 架构: arm64"
echo ""
echo "   • enyan-macos-x64.app"
echo "     - 适用: Intel 芯片 Mac"
echo "     - 架构: x86_64"
echo ""
echo "   • enyan-macos-universal.app"
echo "     - 适用: 所有 Mac (通用版，体积较大)"
echo "     - 架构: arm64 + x86_64"
echo "----------------------------------------------------------------"

ls -lh "$OUTPUT_DIR"

