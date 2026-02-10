#!/usr/bin/env python3
"""
完整圣经音频下载脚本
从 bonpounou.com 下载全部 66 卷中文圣经朗读音频
每章一个 MP3 文件，共约 1189 个文件
"""

import os
import requests
from pathlib import Path
from urllib.parse import quote
import time

DOWNLOAD_DIR = Path("data/bible_assets/audio_full")
BASE_URL = "https://www.bonpounou.com/Bibchineseaudio/{filename}"

# 66 卷书：(书号, 英文名, 章数)
BIBLE_BOOKS = [
    # 旧约 39 卷
    (1, "Genesis", 50),
    (2, "Exodus", 40),
    (3, "Leviticus", 27),
    (4, "Numbers", 36),
    (5, "Deuterenomy", 34),
    (6, "Joshua", 24),
    (7, "Judges", 21),
    (8, "Ruth", 4),
    (9, " 1 Samuel", 31),
    (10, " 2 Samuel", 24),
    (11, " 1 Kings", 22),
    (12, " 2 Kings", 25),
    (13, " 1 Chronicles", 29),
    (14, " 2 Chronicles", 36),
    (15, "Ezra", 10),
    (16, "Nehemiah", 13),
    (17, "Esther", 10),
    (18, "Job", 42),
    (19, "Psalm", 150),
    (20, "Proverbs", 31),
    (21, "Ecclesiastes", 12),
    (22, "Song of Songs", 8),
    (23, "Isaiah", 66),
    (24, "Jeremiah", 52),
    (25, "Lamentations", 5),
    (26, "Ezekiel", 48),
    (27, "Daniel", 12),
    (28, "Hosea", 14),
    (29, "Joel", 3),
    (30, "Amos", 9),
    (31, "Obadiah", 1),
    (32, "Jonah", 4),
    (33, "Micah", 7),
    (34, "Nahum", 3),
    (35, "Habakkuk", 3),
    (36, "Zephaniah", 3),
    (37, "Haggai", 2),
    (38, "Zechariah", 14),
    (39, "Malachi", 4),
    # 新约 27 卷
    (40, "Matthew", 28),
    (41, "Mark", 16),
    (42, "Luke", 24),
    (43, "John", 21),
    (44, "Acts", 28),
    (45, "Romans", 16),
    (46, " 1 Corinthians", 16),
    (47, " 2 Corinthians", 13),
    (48, "Galatians", 6),
    (49, "Ephesians", 6),
    (50, "Philippians", 4),
    (51, "Colossians", 4),
    (52, " 1 Thess", 5),
    (53, " 2 Thess", 3),
    (54, " 1 Timothy", 6),
    (55, " 2 Timothy", 4),
    (56, "Titus", 3),
    (57, "Philemon", 1),
    (58, "Hebrews", 13),
    (59, "James", 5),
    (60, " 1 Peter", 5),
    (61, " 2 Peter", 3),
    (62, " 1 John", 5),
    (63, " 2 John", 1),
    (64, " 3 John", 1),
    (65, "Jude", 1),
    (66, "Revelation", 22),
]


def download_file(url: str, filepath: Path) -> bool:
    """下载单个文件"""
    try:
        if filepath.exists():
            return True  # 跳过已存在文件
            
        response = requests.get(url, stream=True, timeout=60)
        response.raise_for_status()
        
        with open(filepath, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except Exception as e:
        print(f"  ❌ {filepath.name}: {e}")
        return False


def download_book(book_num: int, book_name: str, chapter_count: int):
    """下载一卷书的所有章节"""
    book_dir = DOWNLOAD_DIR / f"{book_num:02d}_{book_name}"
    book_dir.mkdir(parents=True, exist_ok=True)
    
    success = 0
    for ch in range(1, chapter_count + 1):
        # 文件名格式: C01Genesis 01.mp3
        filename = f"C{book_num:02d}{book_name} {ch:02d}.mp3"
        url = BASE_URL.format(filename=quote(filename))
        filepath = book_dir / f"{ch:02d}.mp3"
        
        if download_file(url, filepath):
            success += 1
            print(f"  ✅ {book_name} {ch}/{chapter_count}", end="\r")
        
        time.sleep(0.1)  # 避免请求过快
    
    print(f"  📊 {book_name}: {success}/{chapter_count} 章")
    return success


def main():
    import argparse
    parser = argparse.ArgumentParser(description="完整圣经音频下载脚本")
    parser.add_argument("--book", type=int, help="下载指定书卷编号 (1-66)")
    parser.add_argument("--start", type=int, default=1, help="起始书卷编号")
    parser.add_argument("--end", type=int, default=66, help="结束书卷编号")
    parser.add_argument("--nt", action="store_true", help="仅下载新约 (40-66)")
    parser.add_argument("--ot", action="store_true", help="仅下载旧约 (1-39)")
    args = parser.parse_args()
    
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    
    print("=" * 50)
    print("🎵 完整圣经音频下载工具")
    print(f"📁 保存目录: {DOWNLOAD_DIR.absolute()}")
    print("=" * 50)
    
    # 确定下载范围
    if args.book:
        books = [(n, name, ch) for n, name, ch in BIBLE_BOOKS if n == args.book]
    elif args.nt:
        books = [(n, name, ch) for n, name, ch in BIBLE_BOOKS if n >= 40]
    elif args.ot:
        books = [(n, name, ch) for n, name, ch in BIBLE_BOOKS if n <= 39]
    else:
        books = [(n, name, ch) for n, name, ch in BIBLE_BOOKS 
                 if args.start <= n <= args.end]
    
    total_chapters = sum(ch for _, _, ch in books)
    print(f"📖 准备下载 {len(books)} 卷书，共 {total_chapters} 章")
    print()
    
    total_success = 0
    for book_num, book_name, chapter_count in books:
        print(f"\n📖 {book_num:02d}. {book_name} ({chapter_count} 章)")
        total_success += download_book(book_num, book_name, chapter_count)
    
    print("\n" + "=" * 50)
    print(f"🎉 下载完成! 成功 {total_success}/{total_chapters} 章")
    print(f"📁 音频目录: {DOWNLOAD_DIR.absolute()}")


if __name__ == "__main__":
    main()
