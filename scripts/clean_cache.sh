#!/bin/bash

echo "🧹 正在执行【终极】深度清理项目缓存..."

# 1. 强力终止应用进程
echo "🛑 强力杀掉应用相关进程 (enyan/gracewords)..."
pkill -9 -i "enyan" || true
pkill -9 -i "gracewords" || true

# 2. 深度搜索并物理粉碎下载目录
echo "🔍 正在地毯式搜索下载资源目录 (这可能需要几秒钟)..."

# 搜索包含 packs 或 audio 的目录，并包含 enyan 关键字的路径
TARGET_DIRS=$(find ~/Library/Containers -name "Data" -type d 2>/dev/null | grep -i "enyan")

if [ -n "$TARGET_DIRS" ]; then
    for DATA_DIR in $TARGET_DIRS; do
        DOCS_DIR="$DATA_DIR/Documents"
        echo "📂 找到应用数据根目录: $DATA_DIR"
        
        if [ -d "$DOCS_DIR" ]; then echo "🗑️  清理 Documents 子项..."; rm -rf "$DOCS_DIR"/*; fi
        
        # 3. 清理 macOS UserDefaults (这是最关键的，决定了“已下载”等 UI 状态)
        PREFS_DIR="$DATA_DIR/Library/Preferences"
        if [ -d "$PREFS_DIR" ]; then
             echo "📝 彻底销毁偏好设置 (UserDefaults): $PREFS_DIR"
             rm -f "$PREFS_DIR"/*.plist
        fi
        
        # 4. 清理 Caches
        CACHES_DIR="$DATA_DIR/Library/Caches"
        if [ -d "$CACHES_DIR" ]; then
             echo "🔥 清理系统缓存: $CACHES_DIR"
             rm -rf "$CACHES_DIR"/*
        fi
    done
    echo "✅ 深度清理完成！"
else
    echo "❌ 警告：未能在 ~/Library/Containers 下定位到任何 enyan 相关数据。"
fi

# 检查全局 Application Support
APP_SUPPORT=~/Library/Application\ Support/com.yishulun.enyan
if [ -d "$APP_SUPPORT" ]; then
    echo "🧹 清理 Application Support 目录..."
    rm -rf "$APP_SUPPORT"
fi

echo "🚀 【全部重置完毕】"
echo "请执行以下步骤进行重新测试："
echo "1. 重新运行 App (flutter run 或在 IDE 中启动)"
echo "2. 进入设置页，确认现在状态均已重置为“未下载”"
echo "3. 重新下载并测试同步/跳转功能"
