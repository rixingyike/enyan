import sqlite3
import os

def extract_unique_chars(db_path, output_path):
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    print(f"Reading text from {db_path}...")
    cursor.execute("SELECT text FROM verses")
    rows = cursor.fetchall()
    
    # Also get book names
    cursor.execute("SELECT name_zh FROM books")
    book_names = cursor.fetchall()

    chars = set()
    
    # Constant common punks and numbers to ensure UI stability
    common_chars = "0123456789.:-()[]<>!?,;\"' \"'“”‘’！？，。：；—…（）《》【】"
    chars.update(common_chars)

    for (text,) in rows:
        chars.update(text)
    
    for (name,) in book_names:
        chars.update(name)

    # Filter out whitespace and low-order characters
    unique_list = sorted([c for c in chars if ord(c) > 32])
    unique_text = "".join(unique_list)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(unique_text)
    
    print(f"✅ Extracted {len(unique_list)} unique characters to {output_path}")
    conn.close()

if __name__ == "__main__":
    # Simplified
    extract_unique_chars(
        '/Users/liyi/work/enyan/assets/chs/bible_chs.db', 
        '/Users/liyi/work/enyan/scripts/whitelist_chs.txt'
    )
    # Traditional
    extract_unique_chars(
        '/Users/liyi/work/enyan/assets/cht/bible_cht.db', 
        '/Users/liyi/work/enyan/scripts/whitelist_cht.txt'
    )
