import os
import sqlite3
import requests
from bs4 import BeautifulSoup
import json
import time
import argparse
import re

# Mapping from local book ID to BibleGateway CUVS search alias
BOOK_MAPPING = {
    1: "創 世 記", 2: "出 埃 及 記", 3: "利 未 記", 4: "民 數 記", 5: "申 命 記",
    6: "約 書 亞 記", 7: "士 師 記", 8: "路 得 記", 9: "撒 母 耳 記 上", 10: "撒 母 耳 記 下",
    11: "列 王 紀 上", 12: "列 王 紀 下", 13: "歷 代 志 上", 14: "歷 代 志 下",
    15: "以 斯 拉 記", 16: "尼 希 米 記", 17: "以 斯 帖 記", 18: "約 伯 記",
    19: "詩 篇", 20: "箴 言", 21: "傳 道 書", 22: "雅 歌", 23: "以 賽 亞 書",
    24: "耶 利 米 書", 25: "耶 利 米 哀 歌", 26: "以 西 結 書", 27: "但 以 理 書",
    28: "何 西 阿 書", 29: "約 珥 書", 30: "阿 摩 司 書", 31: "俄 巴 底 亞 書",
    32: "約 拿 書", 33: "彌 迦 書", 34: "那 鴻 書", 35: "哈 巴 谷 書", 
    36: "西 番 雅 書", 37: "哈 該 書", 38: "撒 迦 利 亞", 39: "瑪 拉 基 書",
    40: "马 太 福 音", 41: "马 可 福 音", 42: "路 加 福 音", 43: "约 翰 福 音",
    44: "使 徒 行 傳", 45: "羅 馬 書", 46: "歌 林 多 前 書", 47: "歌 林 多 後 書",
    48: "加 拉 太 書", 49: "以 弗 所 書", 50: "腓 立 比 書", 51: "歌 羅 西 書",
    52: "帖 撒 罗 尼 迦 前 书", 53: "帖 撒 罗 尼 迦 后 书", 54: "提 摩 太 前 書",
    55: "提 摩 太 後 書", 56: "提 多 書", 57: "腓 利 門 書", 58: "希 伯 來 書",
    59: "雅 各 書", 60: "彼 得 前 書", 61: "彼 得 後 書", 62: "約 翰 一 書",
    63: "約 翰 二 書", 64: "約 翰 三 書", 65: "猶 大 書", 66: "启 示 录"
}

def normalize_text(text):
    """Normalize text for structural comparison, ignoring stylistic/variant differences."""
    if not text: return ""
    # Map common variants
    variants = {
        '後': '后', '於': '于', '罢': '吧', '罢': '吧', '罢': '吧',
        '罢': '吧', '裏': '里', '旦': '但', '罢': '吧', '罢': '吧',
        '罢': '吧', '約': '约', '但': '旦', # careful with but/Jordan
    }
    # Keep it simple: remove all punctuation and spaces
    text = re.sub(r'[^\u4e00-\u9fff]', '', text)
    # Basic variant swap (very conservative)
    for k, v in variants.items():
        text = text.replace(k, v)
    return text

def fetch_bg_verses(book_alias, chapter):
    url = f"https://www.biblegateway.com/passage/?search={book_alias}+{chapter}&version=CUVS"
    headers = {"User-Agent": "Mozilla/5.0"}
    
    print(f"Fetching {book_alias} {chapter}...")
    try:
        resp = requests.get(url, headers=headers, timeout=10)
        resp.raise_for_status()
    except Exception as e:
        print(f"Error fetching: {e}")
        return None

    soup = BeautifulSoup(resp.text, 'html.parser')
    verses = {}
    passage = soup.select_one('.passage-content')
    if not passage:
        return None

    current_verse = None
    for item in passage.find_all(['span', 'p']):
        # If it's a verse text span
        if 'text' in item.get('class', []):
            classes = item.get('class', [])
            v_match = None
            for c in classes:
                m = re.match(r'.*?-.*?-(\d+)', c)
                if m:
                    v_match = int(m.group(1))
                    break
            
            if v_match:
                current_verse = v_match
                if current_verse not in verses:
                    verses[current_verse] = ""
                
                # Clone item to modify
                temp_span = BeautifulSoup(str(item), 'html.parser').find('span')
                # Remove verse numbers and footnotes but keep text
                for tag in temp_span.find_all(['sup', 'div', 'h3']):
                    tag.decompose()
                
                text = temp_span.get_text().strip()
                # Remove spaces between characters
                text = re.sub(r'(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])', '', text)
                verses[current_verse] += text

    return verses

def compare_chapter(db_path, book_id, chapter):
    book_alias = BOOK_MAPPING.get(book_id)
    bg_verses = fetch_bg_verses(book_alias, chapter)
    if not bg_verses: return None

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT verse, text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse", (book_id, chapter))
    local_verses = {row[0]: row[1] for row in cursor.fetchall()}
    conn.close()

    diffs = []
    # Check max range
    all_vs = sorted(list(set(bg_verses.keys()) | set(local_verses.keys())))
    
    for v_num in all_vs:
        bg_text = bg_verses.get(v_num, "")
        local_text = local_verses.get(v_num, "")
        
        if normalize_text(bg_text) != normalize_text(local_text):
            diffs.append({
                "verse": v_num,
                "bg": bg_text,
                "local": local_text
            })
    return diffs

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default="assets/bible_chs.db")
    parser.add_argument("--book_id", type=int, default=40)
    parser.add_argument("--chapter_start", type=int, default=1)
    parser.add_argument("--chapter_end", type=int, default=28)
    args = parser.parse_args()

    all_diffs = {}
    for ch in range(args.chapter_start, args.chapter_end + 1):
        diffs = compare_chapter(args.db, args.book_id, ch)
        if diffs:
            all_diffs[ch] = diffs
            print(f"Chapter {ch}: found {len(diffs)} differences.")
        else:
            print(f"Chapter {ch}: OK")
        time.sleep(0.5) # Be kind

    if all_diffs:
        with open("scripts/data_diffs.json", "w", encoding="utf-8") as f:
            json.dump(all_diffs, f, ensure_ascii=False, indent=2)
        
        with open("scripts/fix_bible.sql", "w", encoding="utf-8") as f:
            for ch, diffs in all_diffs.items():
                f.write(f"-- Book {args.book_id} Chapter {ch}\n")
                for d in diffs:
                    if d['bg']:
                        fixed_bg = d['bg'].replace("'", "''")
                        # Preserve original punctuation from BG but clean spaces
                        fixed_bg = "".join(fixed_bg.split())
                        f.write(f"UPDATE verses SET text = '{fixed_bg}' WHERE book_id = {args.book_id} AND chapter = {ch} AND verse = {d['verse']};\n")
        print(f"Results saved to scripts/data_diffs.json and scripts/fix_bible.sql")
    else:
        print("No structural differences found.")

if __name__ == "__main__":
    main()

if __name__ == "__main__":
    main()
