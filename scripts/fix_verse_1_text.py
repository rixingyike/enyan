import sqlite3
import os

db_path = '/Users/liyi/work/enyan/assets/chs/bible_chs.db'

def fix_verses(db_path):
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}")
        return

    print(f"\n--- Checking {db_path} ---")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Query all verse 1 entries
    cursor.execute("""
        SELECT v.id, b.name_zh, v.chapter, v.text 
        FROM verses v 
        JOIN books b ON v.book_id = b.id 
        WHERE v.verse = 1
    """)
    
    rows = cursor.fetchall()
    to_fix = []

    for row_id, book_name, chapter, text in rows:
        chap_str = str(chapter)
        # Check if text starts with chapter number
        if text.startswith(chap_str):
            # Check if it's followed by a space or something else
            # The user said "1 8那时", so '8' followed by '那时'
            # We remove the prefix
            new_text = text[len(chap_str):]
            # Strip leading space if any
            new_text = new_text.lstrip()
            to_fix.append((new_text, row_id, f"{book_name} {chapter}:1", text, new_text))

    if not to_fix:
        print("No redundant chapter numbers found in verse 1.")
    else:
        print(f"Found {len(to_fix)} matches:")
        for _, _, label, old, new in to_fix:
            print(f"[{label}] Old: '{old[:20]}...' -> New: '{new[:20]}...'")

        # Execute update
        for new_content, row_id, _, _, _ in to_fix:
            cursor.execute("UPDATE verses SET text = ? WHERE id = ?", (new_content, row_id))
        
        conn.commit()
        print(f"\nSuccessfully updated {len(to_fix)} rows.")

    conn.close()

if __name__ == "__main__":
    fix_verses('/Users/liyi/work/enyan/assets/chs/bible_chs.db')
    fix_verses('/Users/liyi/work/enyan/assets/cht/bible_cht.db')
