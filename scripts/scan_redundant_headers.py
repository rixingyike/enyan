
import sqlite3
import re

db_path = "assets/chs/bible_chs.db"

def scan_verses():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get all verse 1 entries
    cursor.execute("SELECT book_id, chapter, text FROM verses WHERE verse = 1")
    rows = cursor.fetchall()
    
    # Book mapping for printing
    cursor.execute("SELECT id, name_zh FROM books")
    book_names = dict(cursor.fetchall())
    
    count = 0
    print("Scanning for redundant chapter numbers in Verse 1...")
    print("-" * 50)
    
    for book_id, chapter, text in rows:
        # User says: "凡是第一节，在节数之后，还有一个章数字的"
        # However, usually the DB text doesn't start with the verse number "1".
        # If it DOES start with the chapter number, it's likely redundant.
        # Examples of problematic text:
        # "1 起初..." (In Genesis 1)
        # "40 ... " (In Matthew 40? No, Matthew 40 doesn't exist. Matthew 1 starts with 1).
        
        match = re.match(r'^\s*(\d+)\s*', text)
        if match:
            found_num = int(match.group(1))
            if found_num == chapter:
                count += 1
                print(f"Match found: {book_names[book_id]} Ch {chapter} | Text: {text[:60]}")
                
    conn.close()
    print("-" * 50)
    print(f"Total problematic verses found: {count}")

if __name__ == "__main__":
    scan_verses()
