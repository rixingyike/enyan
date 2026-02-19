#!/usr/bin/env python3
"""
低比特率音频压缩测试脚本 V2
测试目标: 生成 12k, 8k, 6k 版本的 Opus 音频 (16kHz 采样率版本)
优化参数 (User Specified):
  - 采样率: 16000Hz
  - DTX: 开启
  - 模式: VBR, VOIP, Mono
  - Compression Level: 10
  - Metadata: Stripped
"""

import subprocess
from pathlib import Path

INPUT_FILE = Path("data/bible_assets/audio_full/01_Genesis/01.mp3")
OUTPUT_DIR = Path("data/audio_test")

# 比特率配置
BITRATES = ["12k", "8k", "6k"]

def convert_sample_v2(bitrate):
    # 文件名区分: 增加 _16khz 后缀
    output_file = OUTPUT_DIR / f"Genesis_01_{bitrate}_16khz_dtx.opus"
    
    cmd = [
        "ffmpeg", "-y",
        "-i", str(INPUT_FILE),
        "-c:a", "libopus",
        "-b:a", bitrate,
        "-ar", "16000",         # User requested 16000Hz
        "-ac", "1",             # Mono
        "-dtx", "1",            # Enable DTX
        "-application", "voip",
        "-compression_level", "10",
        "-map_metadata", "-1",
        "-vn",
        "-loglevel", "warning",
        str(output_file)
    ]
    
    print(f"⏳ 正在转换 {bitrate} (16kHz) 版本...")
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
        
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    print(f"📂 输入文件: {INPUT_FILE}")
    print(f"📂 输出目录: {OUTPUT_DIR}")
    print("-" * 50)
    
    for br in BITRATES:
        convert_sample_v2(br)
        
    print("-" * 50)
    print("🎉 V2 测试样本生成完毕")

if __name__ == "__main__":
    main()
