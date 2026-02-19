
import sqlite3
import os

db_path = "assets/chs/bible_chs.db"
book_id = 5

conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("SELECT chapter, verse, text FROM verses WHERE book_id = ? ORDER BY chapter, verse", (book_id,))
rows = cursor.fetchall()
conn.close()

for chapter in range(1, 35): # Deuteronomy has 34 chapters
    chapter_rows = [r for r in rows if r[0] == chapter]
    if not chapter_rows: continue
    
    text_lines = [f"申命记 第{chapter}章"] + [r[2] for r in chapter_rows]
    content = "\n".join(text_lines) + "\n"
    
    try:
        encoded = content.encode('utf-8')
        # Check if we can decode it back
        encoded.decode('utf-8')
    except Exception as e:
        print(f"!!! Error in Chapter {chapter}: {e}")
        continue
    
    # Check for specific bytes that might trip up Aeneas if it doesn't like them
    # Though utf-8 is fine, maybe a character is problematic for Aeneas?
    # Let's see if we can find 0xa4 in a weird place.
    raw_bytes = content.encode('utf-8')
    for i, b in enumerate(raw_bytes):
        if b == 0xa4:
            # Check context
            if i == 0 or (raw_bytes[i-1] & 0xc0) != 0xc0:
                 # This would be an invalid UTF-8 if i-1 wasn't a start byte
                 # But encode('utf-8') would have failed.
                 pass

print("Check completed for Book 5.")
