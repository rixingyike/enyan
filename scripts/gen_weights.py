import sqlite3
import json
import os

# Bible Books Metadata (id, name_zh, chapter_count)
BIBLE_BOOKS = [
    (1, "创世记", 50), (2, "出埃及记", 40), (3, "利未记", 27), (4, "民数记", 36), (5, "申命记", 34),
    (6, "约书亚记", 24), (7, "士师记", 21), (8, "路得记", 4), (9, "撒母耳记上", 31), (10, "撒母耳记下", 24),
    (11, "列王纪上", 22), (12, "列王纪下", 25), (13, "历代志上", 29), (14, "历代志下", 36), (15, "以斯拉记", 10),
    (16, "尼希米记", 13), (17, "以斯帖记", 10), (18, "约伯记", 42), (19, "诗篇", 150), (20, "箴言", 31),
    (21, "传道书", 12), (22, "雅歌", 8), (23, "以赛亚书", 66), (24, "耶利米书", 52), (25, "耶利米哀歌", 5),
    (26, "以西结书", 48), (27, "但以理书", 12), (28, "何西阿书", 14), (29, "约珥书", 3), (30, "阿摩司书", 9),
    (31, "俄巴底亚书", 1), (32, "约拿书", 4), (33, "弥迦书", 7), (34, "那鸿书", 3), (35, "哈巴谷书", 3),
    (36, "西番雅书", 3), (37, "哈该书", 2), (38, "撒迦利亚书", 14), (39, "玛拉基书", 4), (40, "马太福音", 28),
    (41, "马可福音", 16), (42, "路加福音", 24), (43, "约翰福音", 21), (44, "使徒行传", 28), (45, "罗马书", 16),
    (46, "哥林多前书", 16), (47, "哥林多后书", 13), (48, "加拉太书", 6), (49, "以弗所书", 6), (50, "腓立比书", 4),
    (51, "歌罗西书", 4), (52, "帖撒罗尼迦前书", 5), (53, "帖撒罗尼迦后书", 3), (54, "提摩太前书", 6), (55, "提摩太后书", 4),
    (56, "提多书", 3), (57, "腓利门书", 1), (58, "希伯来书", 13), (59, "雅各书", 5), (60, "彼得前书", 5),
    (61, "彼得后书", 3), (62, "约翰一书", 5), (63, "约翰二书", 1), (64, "约翰三书", 1), (65, "犹大书", 1),
    (66, "启示录", 22)
]

def get_book_name(book_id):
    for bid, name, _ in BIBLE_BOOKS:
        if bid == book_id:
            return name
    return ""

def generate_weights(db_path, output_json):
    if not os.path.exists(db_path):
        print(f"Skipping {db_path} as it does not exist.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get all book/chapter pairs
    cursor.execute("SELECT DISTINCT book_id, chapter FROM verses ORDER BY book_id, chapter")
    indices = cursor.fetchall()
    
    data = {}
    for book_id, chapter in indices:
        cursor.execute("SELECT text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse", (book_id, chapter))
        verses = cursor.fetchall()
        
        if not verses:
            continue
            
        char_counts = [len(v[0]) for v in verses]
        
        # Calculate title offset (e.g. "创世记 第1章")
        # Note: We use a simplified length estimation.
        # Ideally this should match the actual audio duration ratio, but char count is a good proxy for TTS/reading speed.
        book_name = get_book_name(book_id)
        if not book_name:
            print(f"Warning: Unknown book_id {book_id}")
            title_len = 0
        else:
            # Replicate the title format likely read in the audio
            # Usually: "BookName Chapter N" -> "书名 第N章"
            title_text = f"{book_name} 第{chapter}章"
            title_len = len(title_text)
            
        total = sum(char_counts) + title_len
        
        if total == 0:
            weights = [0.0] * len(char_counts)
        else:
            cumulative = title_len
            weights = []
            for count in char_counts:
                cumulative += count
                weights.append(round(cumulative / total, 6))
        
        if str(book_id) not in data:
            data[str(book_id)] = {}
        data[str(book_id)][str(chapter)] = weights
        
    conn.close()
    
    with open(output_json, 'w', encoding='utf-8') as f:
        json.dump(data, f)
    
    print(f"Generated {output_json}")

if __name__ == "__main__":
    generate_weights("assets/chs/bible_chs.db", "assets/chs/audio_weights_chs.json")
    # CHT db might have different book names if we supported it fully, but for CHT audio weights we are focusing on CHS logic for now as requested? 
    # Actually the user only asked for CHS weights adjustment based on "Heheven" audio which is usually CHS.
    # The original script generated both. Let's keep generating both but be aware CHT might need its own book names if strictly CHT audio is used.
    # However, usually users use CHS audio even for CHT text or vice versa in some apps, or CHT audio has similar title structure.
    # We will apply the same logic.
    generate_weights("assets/cht/bible_cht.db", "assets/cht/audio_weights_cht.json")
