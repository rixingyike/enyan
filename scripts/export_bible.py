import sqlite3
import json
import os

def export_to_json(db_path, output_dir, name_prefix):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get all books
    cursor.execute("SELECT id, name_en, name_zh, chapter_count FROM books")
    books = cursor.fetchall()
    
    # Mapping for common filename aliases if needed, but let's use name_en or code
    # The dir has names like MAT.json, GEN.json
    BOOK_CODES = {
        1: "GEN", 2: "EXO", 3: "LEV", 4: "NUM", 5: "DEU", 6: "JOS", 7: "JDG", 8: "RUT",
        9: "1SA", 10: "2SA", 11: "1KI", 12: "2KI", 13: "1CH", 14: "2CH", 15: "EZR", 16: "NEH", 17: "EST",
        18: "JOB", 19: "PSA", 20: "PRO", 21: "ECC", 22: "SNG", 23: "ISA", 24: "JER", 25: "LAM", 26: "EZK", 27: "DAN",
        28: "HOS", 29: "JOL", 30: "AMO", 31: "OBA", 32: "JNA", 33: "MIC", 34: "NAM", 35: "HAB", 36: "ZEP", 37: "HAG", 38: "ZEC", 39: "MAL",
        40: "MAT", 41: "MRK", 42: "LUK", 43: "JHN", 44: "ACT", 45: "ROM", 46: "1CO", 47: "2CO", 48: "GAL", 49: "EPH", 50: "PHP", 51: "COL",
        52: "1TH", 53: "2TH", 54: "1TI", 55: "2TI", 56: "TIT", 57: "PHM", 58: "HEB", 59: "JAS", 60: "1PE", 61: "2PE", 62: "1JN", 63: "2JN", 64: "3JN", 65: "JUD", 66: "REV"
    }

    for b_id, name_en, name_zh, ch_count in books:
        code = BOOK_CODES.get(b_id, name_en[:3].upper())
        print(f"Exporting {name_zh} ({code})...")
        
        book_data = {
            "name": name_zh,
            "code": code,
            "chapter_count": ch_count,
            "chapters": []
        }
        
        for ch in range(1, ch_count + 1):
            cursor.execute("SELECT verse, text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse", (b_id, ch))
            verses = cursor.fetchall()
            
            chapter_data = {
                "chapter": ch,
                "verses": [{"verse": v, "text": t} for v, t in verses]
            }
            book_data["chapters"].append(chapter_data)
            
        with open(os.path.join(output_dir, f"{code}.json"), "w", encoding="utf-8") as f:
            json.dump(book_data, f, ensure_ascii=False, indent=2)
            
    conn.close()

if __name__ == "__main__":
    # Update CHS
    export_to_json("assets/bible_chs.db", "data/raw_chs", "chs")
    
    # Update CHT (New directory or overwrite raw?)
    # Currently there is no raw_cht, but maybe we should create it for completeness
    export_to_json("assets/bible_cht.db", "data/raw_cht", "cht")
