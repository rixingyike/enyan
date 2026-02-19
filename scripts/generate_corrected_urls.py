#!/usr/bin/env python3
"""
生成修正后的圣经音频 URL 列表
"""

from pathlib import Path
from urllib.parse import quote

BASE_URL = "https://www.bonpounou.com/Bibchineseaudio/{filename}"
OUTPUT_FILE = Path("data/bible_audio_urls.txt")

# 修正后的 66 卷书列表 (与 download_full_audio.py 保持一致)
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

def main():
    print(f"正在生成 URL 列表到 {OUTPUT_FILE} ...")
    
    with open(OUTPUT_FILE, "w") as f:
        for book_num, book_name, chapter_count in BIBLE_BOOKS:
            f.write(f"\n# {book_num:02d}. {book_name.strip()} ({chapter_count} 章)\n")
            for ch in range(1, chapter_count + 1):
                # 文件名格式: C01Genesis 01.mp3
                filename = f"C{book_num:02d}{book_name} {ch:02d}.mp3"
                url = BASE_URL.format(filename=quote(filename))
                f.write(f"{url}\n")
    
    print("✅ 完成!")

if __name__ == "__main__":
    main()
