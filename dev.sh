#!/usr/bin/env bash

# dev.sh - Development Runner

# Helper function to find Flutter
get_flutter() {
    local cmd="$HOME/develop/flutter/bin/flutter"
    if [ ! -x "$cmd" ]; then
        if command -v flutter &> /dev/null; then
            cmd="flutter"
        else
            echo "❌ Error: Flutter not found."
            exit 1
        fi
    fi
    echo "$cmd"
}

FLUTTER_CMD=$(get_flutter)

# Boot iOS Simulator if needed
prepare_ios() {
    echo "🍎 Checking iOS Simulator..."
    if ! xcrun simctl list devices | grep "Booted" > /dev/null; then
        echo "   No booted simulator found. Searching for iPhone..."
        # Try to find an iPhone 16, 15, or 14
        local dev_uuid=$(xcrun simctl list devices | grep -E "iPhone (1[4-6])" | head -n 1 | awk -F '[()]' '{print $(NF-1)}')
        
        if [ -n "$dev_uuid" ]; then
            echo "   Booting Simulator ($dev_uuid)..."
            xcrun simctl boot "$dev_uuid"
            open -a Simulator
            
            # Wait loop
            echo "   Waiting for boot..."
            sleep 5
        else
            echo "❌ No suitable iPhone simulator found to boot."
            exit 1
        fi
    else
        echo "   Simulator already booted."
    fi
}

# Main Logic
MODE=$1
shift # Shift to allow passing extra args to flutter run

case "$MODE" in
    "ios")
        prepare_ios
        echo "🚀 Running on iOS..."
        $FLUTTER_CMD run -d iPhone "$@"
        ;;
    "macos")
        echo "🖥️ Running on macOS..."
        $FLUTTER_CMD run -d macos "$@"
        ;;
    "clean")
        echo "🧹 Cleaning..."
        $FLUTTER_CMD clean
        $FLUTTER_CMD pub get
        cd ios && pod install && cd ..
        cd macos && pod install && cd ..
        ;;
    * )
        echo "Usage: ./dev.sh [ios|macos|clean] [flutter_args]"
        echo "Example: ./dev.sh ios --verbose"
        echo "Defaulting to auto-detection..."
        $FLUTTER_CMD run "$@"
        ;;
esac
