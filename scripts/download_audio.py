#!/usr/bin/env python3
"""
圣经音频下载脚本 v2
从 LibriVox (Archive.org) 下载中文圣经朗读音频
使用正确的 Archive.org 标识符和文件名格式
"""

import os
import requests
from pathlib import Path

DOWNLOAD_DIR = Path("data/bible_assets/audio")

# LibriVox 中文圣经音频源 (已验证的正确格式)
AUDIO_SOURCES = {
    "matthew": {
        "archive_id": "gospel_matthew_chinese_1007_librivox",
        "mp3_prefix": "thegospelofmatthew",
        "mp3_suffix": "_cuv.mp3",
        "file_count": 12,
        "name_zh": "马太福音",
    },
    "mark": {
        "archive_id": "bible_cuv_mark_chinese_1112_librivox",
        "mp3_prefix": "gospelmark",
        "mp3_suffix": "_cuv.mp3",
        "file_count": 16,
        "name_zh": "马可福音",
    },
    "luke": {
        "archive_id": "bible_cuv_luke_chinese_1111_librivox",
        "mp3_prefix": "luke",
        "mp3_suffix": "_cuv.mp3",
        "file_count": 24,
        "name_zh": "路加福音",
    },
    "john": {
        "archive_id": "bible_cuv_nt04_john_1904_librivox",
        "mp3_prefix": "john",
        "mp3_suffix": "_cuv.mp3",
        "file_count": 21,
        "name_zh": "约翰福音",
    },
    "acts": {
        "archive_id": "bible_cuv_23_acts_1308_librivox",
        "mp3_prefix": "actsapostles",
        "mp3_suffix": "_cuv.mp3",
        "file_count": 28,
        "name_zh": "使徒行传",
    },
}

BASE_URL = "https://archive.org/download/{archive_id}/{mp3_prefix}_{num:02d}{mp3_suffix}"


def download_file(url: str, filepath: Path) -> bool:
    """下载单个文件"""
    try:
        if filepath.exists():
            print(f"  ⏭️ 已存在: {filepath.name}")
            return True
            
        response = requests.get(url, stream=True, timeout=120)
        response.raise_for_status()
        
        with open(filepath, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        size_mb = filepath.stat().st_size / 1024 / 1024
        print(f"  ✅ 下载完成: {filepath.name} ({size_mb:.1f}MB)")
        return True
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            print(f"  ⚠️ 文件不存在: {filepath.name}")
        elif e.response.status_code == 503:
            print(f"  ⚠️ 服务器忙: {filepath.name} (稍后重试)")
        else:
            print(f"  ❌ 下载失败: {filepath.name} - {e}")
        return False
    except Exception as e:
        print(f"  ❌ 下载失败: {filepath.name} - {e}")
        return False


def download_book(book_name: str):
    """下载一卷书的所有音频"""
    if book_name.lower() not in AUDIO_SOURCES:
        print(f"❌ 未找到音频: {book_name}")
        available = ", ".join(AUDIO_SOURCES.keys())
        print(f"   可用: {available}")
        return False
    
    config = AUDIO_SOURCES[book_name.lower()]
    book_dir = DOWNLOAD_DIR / book_name.lower()
    book_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"\n📖 正在下载: {config['name_zh']} ({config['file_count']} 个文件)")
    
    success_count = 0
    for i in range(1, config['file_count'] + 1):
        url = BASE_URL.format(
            archive_id=config['archive_id'],
            mp3_prefix=config['mp3_prefix'],
            num=i,
            mp3_suffix=config['mp3_suffix']
        )
        filename = f"{config['mp3_prefix']}_{i:02d}{config['mp3_suffix']}"
        filepath = book_dir / filename
        
        if download_file(url, filepath):
            success_count += 1
    
    print(f"📊 {config['name_zh']}: {success_count}/{config['file_count']} 个文件下载成功")
    return success_count == config['file_count']


def main():
    import argparse
    parser = argparse.ArgumentParser(description="圣经音频下载脚本")
    parser.add_argument("--book", type=str, help="下载指定书卷 (如 matthew)")
    parser.add_argument("--all", action="store_true", help="下载所有可用音频")
    parser.add_argument("--list", action="store_true", help="列出可用音频")
    args = parser.parse_args()
    
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    
    print("=" * 50)
    print("🎵 圣经音频下载工具 v2")
    print("=" * 50)
    
    if args.list:
        print("\n可用音频:")
        for name, config in AUDIO_SOURCES.items():
            print(f"  - {config['name_zh']} ({name}): {config['file_count']} 个文件")
        return
    
    if args.book:
        download_book(args.book)
    elif args.all:
        for book_name in AUDIO_SOURCES.keys():
            download_book(book_name)
    else:
        # 默认下载马太福音
        download_book("matthew")
    
    print("\n" + "=" * 50)
    print("🎉 下载任务完成!")
    print(f"📁 音频目录: {DOWNLOAD_DIR.absolute()}")


if __name__ == "__main__":
    main()
