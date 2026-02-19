import sqlite3
import shutil
import os
from hanziconv import HanziConv

def convert_db(src_path, dst_path):
    print(f"Converting {src_path} to {dst_path}...")
    
    # 1. Copy the source to destination to keep schema and indices
    if os.path.exists(dst_path):
        os.remove(dst_path)
    shutil.copy2(src_path, dst_path)
    
    conn = sqlite3.connect(dst_path)
    cursor = conn.cursor()
    
    # 2. Convert books table
    print("Converting books table...")
    cursor.execute("SELECT id, name_zh FROM books")
    rows = cursor.fetchall()
    for row_id, name_zh in rows:
        name_tr = HanziConv.toTraditional(name_zh)
        cursor.execute("UPDATE books SET name_zh = ? WHERE id = ?", (name_tr, row_id))
        
    # 3. Convert verses table
    print("Converting verses table...")
    cursor.execute("SELECT id, text FROM verses")
    rows = cursor.fetchall()
    
    count = 0
    for row_id, text in rows:
        text_tr = HanziConv.toTraditional(text)
        
        # Post-conversion fixes for Bible CUV (Traditional)
        # 1. hanziconv tends to convert aspect marker '了' to '瞭' (very rare in CUV)
        # We replace all '瞭' with '了' first, then restore the 5 legitimate cases.
        text_tr = text_tr.replace("瞭", "了")
        
        # 2. Restore '瞭' for specific words found in CUV standard
        text_tr = text_tr.replace("了亮", "瞭亮")
        text_tr = text_tr.replace("了望", "瞭望")
        
        cursor.execute("UPDATE verses SET text = ? WHERE id = ?", (text_tr, row_id))
        count += 1
        if count % 1000 == 0:
            print(f"Converted {count} verses...")
            
    conn.commit()
    conn.close()
    print("Done!")

if __name__ == "__main__":
    src = "assets/bible_chs.db"
    dst = "assets/bible_cht.db"
    if os.path.exists(src):
        convert_db(src, dst)
    else:
        print(f"Source database {src} not found!")
