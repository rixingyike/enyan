#!/bin/bash
# 清理旧的、命名错误的音频目录

BASE_DIR="data/bible_assets/audio_full"
BAD_DIRS=(
    "09_1Samuel"
    "10_2Samuel"
    "11_1Kings"
    "12_2Kings"
    "13_1Chronicles"
    "14_2Chronicles"
    "22_SongofSolomon"
    "46_1Corinthians"
    "47_2Corinthians"
    "52_1Thessalonians"
    "53_2Thessalonians"
    "54_1Timothy"
    "55_2Timothy"
    "60_1Peter"
    "61_2Peter"
    "62_1John"
    "63_2John"
    "64_3John"
)

echo "开始清理旧目录..."
for dir_name in "${BAD_DIRS[@]}"; do
    full_path="$BASE_DIR/$dir_name"
    if [ -d "$full_path" ]; then
        echo "Removing $full_path"
        rm -rf "$full_path"
    else
        echo "Not found: $full_path (already removed or not created)"
    fi
done
echo "清理完成!"
