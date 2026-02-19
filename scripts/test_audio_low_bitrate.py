#!/usr/bin/env python3
"""
低比特率音频压缩测试脚本
测试目标: 生成 12k, 8k, 6k 版本的 Opus 音频用于质量对比
优化参数:
  - 采样率: 8000Hz (Narrowband)
  - DTX: 开启 (不连续传输)
  - 静音修剪: 移除开头和结尾的静音
  - 模式: VBR, VOIP, Mono
"""

import subprocess
from pathlib import Path

INPUT_FILE = Path("data/bible_assets/audio_full/01_Genesis/01.mp3")
OUTPUT_DIR = Path("data/audio_test")

# 比特率配置
BITRATES = ["12k", "8k", "6k"]

# FFmpeg 基础命令
# -af silenceremove=start_periods=1:start_duration=0.1:start_threshold=-50dB:stop_periods=1:stop_duration=1:stop_threshold=-50dB
# 解释:
# start_periods=1: 移除开头的一段静音
# stop_periods=1: 移除结尾的一段静音 (注意: silenceremove 对结尾静音的处理有时比较微妙，这里尝试通用参数)
SILENCE_FILTER = "silenceremove=start_periods=1:start_duration=0.1:start_threshold=-50dB:stop_periods=-1:stop_duration=1:stop_threshold=-50dB"

def convert_sample(bitrate):
    output_file = OUTPUT_DIR / f"Genesis_01_{bitrate}_narrow_dtx.opus"
    
    cmd = [
        "ffmpeg", "-y",
        "-i", str(INPUT_FILE),
        "-c:a", "libopus",
        "-b:a", bitrate,
        "-vbr", "on",
        "-compression_level", "10",
        "-application", "voip",
        "-ar", "8000",          # Narrowband
        "-ac", "1",             # Mono
        "-map_metadata", "-1",  # Strip metadata
        "-dtx", "1",            # Enable DTX
        "-af", SILENCE_FILTER,  # Silence removal
        "-vn",
        "-loglevel", "warning",
        str(output_file)
    ]
    
    print(f"⏳ 正在转换 {bitrate} 版本...")
    try:
        start_size = INPUT_FILE.stat().st_size
        subprocess.run(cmd, check=True)
        end_size = output_file.stat().st_size
        compression_ratio = (1 - end_size / start_size) * 100
        print(f"✅ 完成: {output_file.name}")
        print(f"   体积: {start_size/1024:.1f}KB -> {end_size/1024:.1f}KB (优化率: {compression_ratio:.1f}%)")
    except subprocess.CalledProcessError as e:
        print(f"❌ 转换失败: {e}")

def main():
    if not INPUT_FILE.exists():
        print(f"❌ 输入文件不存在: {INPUT_FILE}")
        return
        
    print(f"📂 输入文件: {INPUT_FILE}")
    print(f"📂 输出目录: {OUTPUT_DIR}")
    print("-" * 50)
    
    for br in BITRATES:
        convert_sample(br)
        
    print("-" * 50)
    print("🎉 所有测试样本生成完毕")

if __name__ == "__main__":
    main()
