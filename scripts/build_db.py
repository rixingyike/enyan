#!/usr/bin/env python3
"""
从和合本 JSON 构建 SQLite 数据库
用于《大字有声圣经》App
"""

import json
import sqlite3
from pathlib import Path

# 66卷书中英文对照
BOOK_NAMES = {
    "Genesis": "创世记",
    "Exodus": "出埃及记",
    "Leviticus": "利未记",
    "Numbers": "民数记",
    "Deuteronomy": "申命记",
    "Joshua": "约书亚记",
    "Judges": "士师记",
    "Ruth": "路得记",
    "1 Samuel": "撒母耳记上",
    "2 Samuel": "撒母耳记下",
    "1 Kings": "列王纪上",
    "2 Kings": "列王纪下",
    "1 Chronicles": "历代志上",
    "2 Chronicles": "历代志下",
    "Ezra": "以斯拉记",
    "Nehemiah": "尼希米记",
    "Esther": "以斯帖记",
    "Job": "约伯记",
    "Psalms": "诗篇",
    "Proverbs": "箴言",
    "Ecclesiastes": "传道书",
    "Song of Solomon": "雅歌",
    "Isaiah": "以赛亚书",
    "Jeremiah": "耶利米书",
    "Lamentations": "耶利米哀歌",
    "Ezekiel": "以西结书",
    "Daniel": "但以理书",
    "Hosea": "何西阿书",
    "Joel": "约珥书",
    "Amos": "阿摩司书",
    "Obadiah": "俄巴底亚书",
    "Jonah": "约拿书",
    "Micah": "弥迦书",
    "Nahum": "那鸿书",
    "Habakkuk": "哈巴谷书",
    "Zephaniah": "西番雅书",
    "Haggai": "哈该书",
    "Zechariah": "撒迦利亚书",
    "Malachi": "玛拉基书",
    "Matthew": "马太福音",
    "Mark": "马可福音",
    "Luke": "路加福音",
    "John": "约翰福音",
    "Acts": "使徒行传",
    "Romans": "罗马书",
    "1 Corinthians": "哥林多前书",
    "2 Corinthians": "哥林多后书",
    "Galatians": "加拉太书",
    "Ephesians": "以弗所书",
    "Philippians": "腓立比书",
    "Colossians": "歌罗西书",
    "1 Thessalonians": "帖撒罗尼迦前书",
    "2 Thessalonians": "帖撒罗尼迦后书",
    "1 Timothy": "提摩太前书",
    "2 Timothy": "提摩太后书",
    "Titus": "提多书",
    "Philemon": "腓利门书",
    "Hebrews": "希伯来书",
    "James": "雅各书",
    "1 Peter": "彼得前书",
    "2 Peter": "彼得后书",
    "1 John": "约翰一书",
    "2 John": "约翰二书",
    "3 John": "约翰三书",
    "Jude": "犹大书",
    "Revelation": "启示录",
}


def build_database(json_path: Path, db_path: Path):
    """从 JSON 构建 SQLite 数据库"""
    print(f"📖 读取 JSON: {json_path}")
    with open(json_path, "r", encoding="utf-8-sig") as f:
        data = json.load(f)
    
    print(f"   共 {len(data)} 卷书")
    
    # 删除旧数据库
    if db_path.exists():
        db_path.unlink()
    
    # 创建数据库
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 创建表
    cursor.execute("""
    CREATE TABLE books (
        id INTEGER PRIMARY KEY,
        name_en TEXT NOT NULL,
        name_zh TEXT NOT NULL,
        chapter_count INTEGER NOT NULL
    )
    """)
    
    cursor.execute("""
    CREATE TABLE verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id)
    )
    """)
    
    cursor.execute("""
    CREATE INDEX idx_verses_book_chapter ON verses(book_id, chapter)
    """)
    
    # 导入数据
    total_verses = 0
    for book_id, book_data in enumerate(data, start=1):
        # 获取书名 (JSON 格式可能是 {"name": "...", "chapters": [...]} 或直接是章节数组)
        if isinstance(book_data, dict):
            name_en = book_data.get("name", f"Book {book_id}")
            chapters = book_data.get("chapters", [])
        else:
            # 如果是列表，假设是章节列表
            name_en = list(BOOK_NAMES.keys())[book_id - 1] if book_id <= len(BOOK_NAMES) else f"Book {book_id}"
            chapters = book_data
        
        name_zh = BOOK_NAMES.get(name_en, name_en)
        chapter_count = len(chapters)
        
        # 插入书卷
        cursor.execute(
            "INSERT INTO books (id, name_en, name_zh, chapter_count) VALUES (?, ?, ?, ?)",
            (book_id, name_en, name_zh, chapter_count)
        )
        
        # 插入经文
        for ch_idx, chapter_data in enumerate(chapters, start=1):
            # Compatibility: Scraper outputs dict {"chapter": N, "verses": [...]}, Legacy is list of strings
            current_chapter_num = ch_idx
            verses_list = []
            
            if isinstance(chapter_data, dict) and "verses" in chapter_data:
                # Scraper format
                current_chapter_num = chapter_data.get("chapter", ch_idx)
                verses_list = chapter_data["verses"]
            elif isinstance(chapter_data, list):
                # Legacy format
                verses_list = chapter_data

            for v_item in verses_list:
                v_num = 0
                v_text = ""
                
                if isinstance(v_item, dict):
                    # Scraper format: {"verse": 1, "text": "..."}
                    v_num = v_item.get("verse")
                    v_text = v_item.get("text")
                elif isinstance(v_item, str):
                    # Legacy format: "..." (index is verse num)
                    # We can't rely on index if we mix, but for legacy it was enumerated (lines 147 old)
                    # Wait, legacy 'enumerate(chapter_verses, start=1)' meant index is verse num.
                    # Here we are iterating. If strings, we need counter.
                    pass 
                
                if isinstance(v_item, str):
                     # Handle legacy enumeration manually?
                     # Let's use enumerate structure again if it's a list of strings
                     continue # Handled below
                
                if v_num and v_text:
                    cursor.execute(
                        "INSERT INTO verses (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
                        (book_id, current_chapter_num, v_num, v_text)
                    )
                    total_verses += 1
            
            # Legacy fallback loop for list of strings
            if isinstance(verses_list, list) and len(verses_list) > 0 and isinstance(verses_list[0], str):
                 for v_idx, verse_text in enumerate(verses_list, start=1):
                    cursor.execute(
                        "INSERT INTO verses (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
                        (book_id, current_chapter_num, v_idx, verse_text)
                    )
                    total_verses += 1
        
        print(f"   ✅ {name_zh} ({name_en}): {chapter_count} 章")
    
    conn.commit()
    conn.close()
    
    print(f"\n🎉 数据库构建完成: {db_path}")
    print(f"   📊 共 {len(data)} 卷, {total_verses} 节经文")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="构建圣经 SQLite 数据库")
    parser.add_argument("--input", type=str, default="data/bible_assets/cuv_bible_text.json", help="输入 JSON 文件")
    parser.add_argument("--output", type=str, default="assets/bible.db", help="输出数据库路径")
    args = parser.parse_args()
    
    json_path = Path(args.input)
    db_path = Path(args.output)
    
    if not json_path.exists():
        print(f"❌ JSON 文件不存在: {json_path}")
        print("   请先运行: python scripts/download_bible.py --text")
        return
    
    db_path.parent.mkdir(parents=True, exist_ok=True)
    build_database(json_path, db_path)


if __name__ == "__main__":
    main()
