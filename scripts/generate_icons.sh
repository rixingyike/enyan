#!/bin/bash
# 自动生成所有平台的 App 图标
# 使用前确保已运行: flutter pub get

echo "Generating App Icons for all platforms..."
flutter pub run flutter_launcher_icons

echo "Done! Icons updated."
