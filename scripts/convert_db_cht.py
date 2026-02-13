import sqlite3
import opencc
import os
import shutil

SRC_DB = 'assets/chs/bible_chs.db'
DST_DB = 'assets/cht/bible_cht.db'

def convert_db():
    if not os.path.exists(SRC_DB):
        print(f"❌ Source DB not found: {SRC_DB}")
        return

    # Create a copy/overwrite destination
    print(f"📦 Copying {SRC_DB} to {DST_DB}...")
    shutil.copyfile(SRC_DB, DST_DB)
    
    # Initialize OpenCC (Simplified to Traditional)
    cc = opencc.OpenCC('s2t')
    
    conn = sqlite3.connect(DST_DB)
    cursor = conn.cursor()
    
    try:
        # 1. Convert Books Table
        print("📖 Converting 'books' table...")
        cursor.execute("SELECT id, name_zh FROM books")
        books = cursor.fetchall()
        for book_id, name_zh in books:
            name_cht = cc.convert(name_zh)
            cursor.execute("UPDATE books SET name_zh = ? WHERE id = ?", (name_cht, book_id))
        
        # 2. Convert Verses Table
        print("📜 Converting 'verses' table (this may take a while)...")
        # Optimization: Fetch all, convert, update in batches
        cursor.execute("SELECT id, text FROM verses")
        # Use fetchmany for memory efficiency if db is huge, but bible db is ~5MB text so fetchall is fine.
        rows = cursor.fetchall()
        
        updates = []
        for row_id, text_chs in rows:
            text_cht = cc.convert(text_chs)
            updates.append((text_cht, row_id))
            
        print(f"🔄 Applying {len(updates)} updates to 'verses'...")
        cursor.executemany("UPDATE verses SET text = ? WHERE id = ?", updates)
        
        conn.commit()
        print(f"✅ Successfully converted {DST_DB} to Traditional Chinese.")
        
    except Exception as e:
        print(f"❌ Error during conversion: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    convert_db()
