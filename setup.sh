#!/usr/bin/env bash
set -e

# setup.sh - EnYan Project Initialization Script

echo "🔍 Checking Environment..."

# Function to find flutter executable
find_flutter() {
    if command -v flutter &> /dev/null; then
        echo "flutter"
        return
    fi
    
    # Common paths for flutter on Mac
    local common_paths=(
        "$HOME/develop/flutter/bin/flutter"
        "$HOME/flutter/bin/flutter"
        "$HOME/development/flutter/bin/flutter"
        "/opt/homebrew/bin/flutter"
        "/usr/local/bin/flutter"
    )

    for path in "${common_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return
        fi
    done
    
    echo ""
}

FLUTTER_CMD=$(find_flutter)

if [ -z "$FLUTTER_CMD" ]; then
    echo "❌ Error: Flutter SDK not found."
    echo "Please ensure Flutter is installed and added to your PATH."
    echo "Or update this script with your Flutter path."
    exit 1
fi

echo "✅ Flutter found at: $FLUTTER_CMD"
$FLUTTER_CMD --version

echo "🚀 Initializing Flutter Project..."

# Check if pubspec.yaml exists to avoid re-creation errors or unwanted overwrites
if [ -f "pubspec.yaml" ]; then
    echo "⚠️  Project seems to be already initialized (pubspec.yaml exists)."
    echo "Skipping 'flutter create'."
else
    # Create project in current directory
    # org: com.gracewords, project-name: enyan (using 'enyan' as per directory name, or 'gracewords' as per plan? 
    # Plan mentioned 'gracewords', let's stick to 'gracewords' as package name but directory is 'enyan')
    # Actually, flutter create . uses current dir name as default, but we can override project name.
    # Let's use 'gracewords' as the Dart package name as planned.
    
    $FLUTTER_CMD create . --org com.gracewords --project-name gracewords --platforms ios,android
    echo "✅ Flutter project created."
fi

echo "🧹 Cleaning up default files..."
if [ -f "lib/main.dart" ]; then
    # Backup original main.dart just in case
    mv lib/main.dart lib/main.dart.bak
    echo "✅ Moved default lib/main.dart to lib/main.dart.bak"
    
    # Create a minimal Clean Architecture friendly main.dart
    cat > lib/main.dart <<EOF
import 'package:flutter/material.dart';

void main() {
  runApp(const GraceWordsApp());
}

class GraceWordsApp extends StatelessWidget {
  const GraceWordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grace Words',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFF8E1)), // Sheepskin color
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Grace Words - EnYan Big Text Version'),
        ),
      ),
    );
  }
}
EOF
    echo "✅ Created new skeleton lib/main.dart"
fi

echo "📂 Creating Directory Structure..."
mkdir -p lib/core/utils
mkdir -p lib/core/network
mkdir -p lib/core/error
mkdir -p lib/features

echo "✅ Directory structure created."

echo "🎉 Setup Complete! Run './dev.sh' to start development (after creating it)."
