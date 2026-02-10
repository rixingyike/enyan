#!/usr/bin/env python3
"""
圣经资源下载脚本
从开源项目下载《和合本》文本 (JSON) 与音频 (MP3)
"""

import os
import json
import zipfile
import requests
from pathlib import Path

# ============ 配置区 ============
DOWNLOAD_DIR = Path("data/bible_assets")

# 文本来源：thiagobodruk/bible 开源库
TEXT_URL = "https://raw.githubusercontent.com/thiagobodruk/bible/master/json/zh_cuv.json"

# 音频来源：LibriVox 公有领域朗读版
# LibriVox 按书卷分别录制，以下是全部可用的中文圣经音频
AUDIO_SOURCES = {
    # 新约
    "matthew": "https://archive.org/download/gospel_matthew_chinese_1007_librivox/gospel_matthew_chinese_1007_librivox_vbr_mp3.zip",
    "mark": "https://archive.org/download/mark_chinese_librivox/mark_chinese_librivox_vbr_mp3.zip",
    "luke": "https://archive.org/download/luke_chinese_librivox/luke_chinese_librivox_vbr_mp3.zip",
    "john": "https://archive.org/download/john_chinese_librivox/john_chinese_librivox_vbr_mp3.zip",
    "acts": "https://archive.org/download/acts_chinese_librivox/acts_chinese_librivox_vbr_mp3.zip",
    "romans": "https://archive.org/download/romans_chinese_librivox/romans_chinese_librivox_vbr_mp3.zip",
    # 旧约
    "genesis": "https://archive.org/download/genesis_chinese_librivox/genesis_chinese_librivox_vbr_mp3.zip",
    "exodus": "https://archive.org/download/exodus_chinese_librivox/exodus_chinese_librivox_vbr_mp3.zip",
    "psalms": "https://archive.org/download/psalms_chinese_librivox/psalms_chinese_librivox_vbr_mp3.zip",
    "proverbs": "https://archive.org/download/proverbs_chinese_librivox/proverbs_chinese_librivox_vbr_mp3.zip",
}


def download_file(url: str, filepath: Path) -> bool:
    """下载文件并显示进度"""
    try:
        print(f"📥 正在下载: {filepath.name}...")
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        with open(filepath, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total_size > 0:
                    pct = downloaded * 100 // total_size
                    print(f"\r   进度: {pct}% ({downloaded // 1024 // 1024}MB/{total_size // 1024 // 1024}MB)", end="")
        
        print(f"\n✅ 完成: {filepath}")
        return True
    except Exception as e:
        print(f"\n❌ 下载失败 ({filepath.name}): {e}")
        return False


def extract_zip(zip_path: Path, extract_dir: Path):
    """解压 ZIP 文件"""
    if not zip_path.exists():
        return
    
    print(f"📦 解压: {zip_path.name}...")
    extract_dir.mkdir(parents=True, exist_ok=True)
    
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(extract_dir)
    
    print(f"✅ 解压完成: {extract_dir}")


def download_text():
    """下载圣经文本"""
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    text_path = DOWNLOAD_DIR / "cuv_bible_text.json"
    
    if text_path.exists():
        print(f"⏭️ 文本已存在，跳过: {text_path}")
        return text_path
    
    if download_file(TEXT_URL, text_path):
        # 验证 JSON
        with open(text_path, "r", encoding="utf-8-sig") as f:
            data = json.load(f)
            book_count = len(data)
            print(f"   📖 载入 {book_count} 卷书")
        return text_path
    return None


def download_audio(book_name: str = None):
    """下载音频文件"""
    audio_dir = DOWNLOAD_DIR / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    
    sources = AUDIO_SOURCES
    if book_name:
        if book_name.lower() in AUDIO_SOURCES:
            sources = {book_name.lower(): AUDIO_SOURCES[book_name.lower()]}
        else:
            print(f"❌ 未找到音频: {book_name}")
            available = ", ".join(AUDIO_SOURCES.keys())
            print(f"   可用: {available}")
            return
    
    for name, url in sources.items():
        zip_path = audio_dir / f"{name}_mp3.zip"
        extract_path = audio_dir / name
        
        if extract_path.exists() and any(extract_path.glob("*.mp3")):
            print(f"⏭️ 音频已存在，跳过: {name}")
            continue
        
        if download_file(url, zip_path):
            extract_zip(zip_path, extract_path)
            # 删除 ZIP 以节省空间
            zip_path.unlink()


def main():
    import argparse
    parser = argparse.ArgumentParser(description="圣经资源下载脚本")
    parser.add_argument("--text", action="store_true", help="仅下载文本")
    parser.add_argument("--audio", type=str, help="下载指定书卷音频 (如 matthew)")
    parser.add_argument("--all-audio", action="store_true", help="下载所有可用音频")
    args = parser.parse_args()
    
    print("=" * 50)
    print("🎯 圣经资源下载工具")
    print("=" * 50)
    
    if args.text or (not args.audio and not args.all_audio):
        download_text()
    
    if args.audio:
        download_audio(args.audio)
    elif args.all_audio:
        download_audio()
    
    print("\n" + "=" * 50)
    print("🎉 下载任务完成！")
    print(f"📁 资源目录: {DOWNLOAD_DIR.absolute()}")


if __name__ == "__main__":
    main()
