#!/usr/bin/env python3
"""
批量音频转换脚本: MP3 -> Opus (16k Low Quality / Speech Optimized)
功能:
- 遍历 data/bible_assets/audio_full 下的所有 MP3 文件
- 转换并保存到 data/bible_assets/audio_opus_16k
- 保持原有目录结构
- 极致压缩参数:
  - 16k bitrate VBR
  - 16kHz sample rate
  - Mono (1 channel)
  - VOIP mode
  - Compression Level 10
  - Strip metadata
"""

import os
import subprocess
from pathlib import Path
import concurrent.futures
import time

# 配置
SOURCE_DIR = Path("data/hehemp3")
TARGET_DIR = Path("data/opus_6k")

# FFmpeg 终极压缩命令
# ffmpeg -i input.mp3 -c:a libopus -b:a 16k -vbr on -compression_level 10 -application voip -ar 16000 -ac 1 -map_metadata -1 -vn output_16k.opus
FFMPEG_CMD = [
    "ffmpeg", 
    "-threads", "1",          # 限制单实例线程，避免并行时 CPU 爆炸
    "-i", "{input}", 
    "-c:a", "libopus", 
    "-b:a", "16k", 
    "-vbr", "on", 
    "-compression_level", "10", 
    "-application", "voip", 
    "-ar", "16000", 
    "-ac", "1",               # 单声道
    "-map_metadata", "-1",    # 剔除元数据
    "-vn",                    # 去除视频流
    "-y", 
    "-loglevel", "error",     # 减少日志
    "{output}"
]

MAX_WORKERS = os.cpu_count()  # 并行进程数

def convert_file(file_info):
    """转换单个文件"""
    src_path, dst_path = file_info
    
    #断点续传: 如果目标文件已存在且大小不为0，跳过
    if dst_path.exists() and dst_path.stat().st_size > 0:
        return True, f"Skipped: {dst_path.name}"
    
    # 确保目标目录存在
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    
    # 构建命令
    cmd = [arg.format(input=str(src_path), output=str(dst_path)) for arg in FFMPEG_CMD]
    
    try:
        # 运行 FFmpeg
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return True, f"Converted: {dst_path.name}"
        else:
            return False, f"Error converting {src_path.name}: {result.stderr}"
    except Exception as e:
        return False, f"Exception converting {src_path.name}: {str(e)}"

def main():
    print("=" * 60)
    print("📉 极致音频压缩工具 (MP3 -> Opus 16k Speech)")
    print(f"📂 源目录: {SOURCE_DIR}")
    print(f"📂 目标目录: {TARGET_DIR}")
    print(f"🚀 并行进程数: {MAX_WORKERS}")
    print("=" * 60)
    
    if not SOURCE_DIR.exists():
        print(f"❌ 源目录不存在: {SOURCE_DIR}")
        return

    # 1. 扫描所有 MP3 文件
    print("\n🔍 正在扫描文件...")
    files_to_convert = []
    
    for root, dirs, files in os.walk(SOURCE_DIR):
        for file in files:
            if file.lower().endswith(".mp3"):
                src_path = Path(root) / file
                
                # 计算目标路径
                rel_path = src_path.relative_to(SOURCE_DIR)
                dst_path = TARGET_DIR / rel_path.with_suffix(".opus")
                
                files_to_convert.append((src_path, dst_path))
    
    total_files = len(files_to_convert)
    print(f"✅ 找到 {total_files} 个 MP3 文件")
    
    if total_files == 0:
        return

    # 2. 开始转换
    print("\n▶️ 开始转换...")
    start_time = time.time()
    success_count = 0
    fail_count = 0
    
    # 打印初始进度
    print(f"\r⏳ 进度: 0/{total_files} (0.0%)", end="")

    with concurrent.futures.ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # 提交所有任务
        futures = {executor.submit(convert_file, info): info for info in files_to_convert}
        
        # 处理结果
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            success, message = future.result()
            if success:
                success_count += 1
            else:
                fail_count += 1
                print(f"\n❌ 转换失败: {message}")
            
            # 实时进度条
            if (i + 1) % 5 == 0 or (i + 1) == total_files:
                percent = (i + 1) / total_files * 100
                elapsed = time.time() - start_time
                speed = (i + 1) / elapsed if elapsed > 0 else 0
                remaining = (total_files - (i + 1)) / speed if speed > 0 else 0
                
                print(f"\r⏳ 进度: {i+1}/{total_files} ({percent:.1f}%) - 速度: {speed:.1f}个/秒 - 剩余: {remaining/60:.1f}分", end="")
    
    end_time = time.time()
    duration = end_time - start_time
    
    print("\n\n" + "=" * 60)
    print(f"🎉 转换完成!")
    print(f"⏱️ 总耗时: {duration/60:.1f} 分钟")
    print(f"✅ 成功: {success_count}")
    print(f"❌ 失败: {fail_count}")
    print(f"📂 输出目录: {TARGET_DIR.absolute()}")

if __name__ == "__main__":
    main()
