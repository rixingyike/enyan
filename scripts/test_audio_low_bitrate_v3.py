#!/usr/bin/env python3
"""
低比特率音频压缩测试脚本 V3
测试目标: 对比特定配置的 Opus 音频质量
输出目录: data/audio_test/3

测试方案:
1. **6k 窄带**: 6kbps @ 8000Hz (减少高频杂讯)
2. **8k 宽带**: 8kbps @ 16000Hz (声音更清脆)

通用参数:
- DTX: 开启
- 模式: VBR, VOIP, Mono
- Compression Level: 10
- Metadata: Stripped
"""

import subprocess
from pathlib import Path

INPUT_FILE = Path("data/bible_assets/audio_full/01_Genesis/01.mp3")
OUTPUT_DIR = Path("data/audio_test/3")

CONFIGS = [
    {
        "name": "6k_base",
        "bitrate": "6k",
        "sample_rate": "8000",
        "desc": "6kbps @ 8kHz (Narrowband)"
    },
    {
        "name": "8k_high",
        "bitrate": "8k",
        "sample_rate": "16000",
        "desc": "8kbps @ 16kHz (Wideband)"
    }
]

def convert_v3(config):
    output_filename = f"{config['name']}.opus"
    output_file = OUTPUT_DIR / output_filename
    
    cmd = [
        "ffmpeg", "-y",
        "-i", str(INPUT_FILE),
        "-c:a", "libopus",
        "-b:a", config["bitrate"],
        "-ar", config["sample_rate"],
        "-ac", "1",             # Mono
        "-dtx", "1",            # Enable DTX
        "-application", "voip",
        "-compression_level", "10",
        "-map_metadata", "-1",
        "-vn",
        "-loglevel", "warning",
        str(output_file)
    ]
    
    print(f"⏳ 正在转换: {config['desc']} ...")
    try:
        start_size = INPUT_FILE.stat().st_size
        subprocess.run(cmd, check=True)
        end_size = output_file.stat().st_size
        compression_ratio = (1 - end_size / start_size) * 100
        print(f"✅ 完成: {output_filename}")
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
    
    for config in CONFIGS:
        convert_v3(config)
        
    print("-" * 50)
    print("🎉 V3 测试样本生成完毕")

if __name__ == "__main__":
    main()
