#!/usr/bin/env python3
"""
批量音频转换脚本: MP3 -> Opus
功能:
- 遍历 data/bible_assets/audio_full 下的所有 MP3 文件
- 转换并保存到 data/bible_assets/audio_opus
- 保持原有目录结构
- 使用 ffmpeg 参数: -c:a libopus -b:a 24k -vn
- 支持多进程并行转换
"""

import os
import subprocess
from pathlib import Path
import concurrent.futures
import time
import shutil

# 配置
SOURCE_DIR = Path("data/bible_assets/audio_full")
TARGET_DIR = Path("data/bible_assets/audio_opus")
FFMPEG_CMD = ["ffmpeg", "-threads", "1", "-i", "{input}", "-c:a", "libopus", "-b:a", "24k", "-vn", "-y", "-loglevel", "error", "{output}"]
MAX_WORKERS = os.cpu_count()  # 根据 CPU 核心数决定并行度

def convert_file(file_info):
    """转换单个文件"""
    src_path, dst_path = file_info
    
    # 如果目标文件已存在且大小不为0，跳过
    if dst_path.exists() and dst_path.stat().st_size > 0:
        return True, f"Skipped: {dst_path.name}"
    
    # 确保目标目录存在
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    
    # 构建命令
    cmd = [arg.format(input=str(src_path), output=str(dst_path)) for arg in FFMPEG_CMD]
    
    try:
        # 运行 FFmpeg，捕获输出以避免刷屏，但在出错时打印
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return True, f"Converted: {dst_path.name}"
        else:
            return False, f"Error converting {src_path.name}: {result.stderr}"
    except Exception as e:
        return False, f"Exception converting {src_path.name}: {str(e)}"

def main():
    print("=" * 50)
    print("🎵 音频格式转换工具 (MP3 -> Opus)")
    print(f"📂 源目录: {SOURCE_DIR}")
    print(f"📂 目标目录: {TARGET_DIR}")
    print(f"🚀 并行进程数: {MAX_WORKERS}")
    print("=" * 50)
    
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
    
    with concurrent.futures.ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
        # 提交所有任务
        futures = {executor.submit(convert_file, info): info for info in files_to_convert}
        
        # 处理结果
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            success, message = future.result()
            if success:
                success_count += 1
                # print(f"[{i+1}/{total_files}] ✅ {message}") # 减少刷屏，只打印进度条或简略信息
                print(f"\r✅ 进度: {i+1}/{total_files} (成功: {success_count}, 失败: {fail_count})", end="")
            else:
                fail_count += 1
                print(f"\n[{i+1}/{total_files}] ❌ {message}")
    
    end_time = time.time()
    duration = end_time - start_time
    
    print("\n\n" + "=" * 50)
    print(f"🎉 转换完成!")
    print(f"⏱️ 耗时: {duration:.1f} 秒")
    print(f"✅ 成功: {success_count}")
    print(f"❌ 失败: {fail_count}")
    print(f"📂 输出目录: {TARGET_DIR.absolute()}")

if __name__ == "__main__":
    main()
