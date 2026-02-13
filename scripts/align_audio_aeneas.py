
import os
import sqlite3
import json
import subprocess
from aeneas.executetask import ExecuteTask
from aeneas.task import Task

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

def get_verses(db_path, book_id, chapter):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT verse, text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse", (book_id, chapter))
    verses = cursor.fetchall()
    conn.close()
    return [v[1] for v in verses]

def align_chapter(audio_path, text_lines, output_format="json"):
    # Create temp text file
    temp_text_path = "temp_align.txt"
    with open(temp_text_path, "w", encoding="utf-8") as f:
        for line in text_lines:
            f.write(line + "\n")

    # Configure Task
    config_string = "task_language=cmn|is_text_type=plain|os_task_file_format=json"
    task = Task(config_string=config_string)
    task.audio_file_path_absolute = os.path.abspath(audio_path)
    task.text_file_path_absolute = os.path.abspath(temp_text_path)

    # Run Task
    try:
        ExecuteTask(task).execute()
        return task.sync_map_leaves()
    except Exception as e:
        print(f"Error alignment: {e}")
        return None
    finally:
        if os.path.exists(temp_text_path):
            os.remove(temp_text_path)

def main():
    db_path = "assets/chs/bible_chs.db"
    output_file = "assets/chs/audio_timestamps_chs.json"
    audio_base_dir = "data/hehemp3"
    
    # Load existing results if available
    results = {}
    if os.path.exists(output_file):
        with open(output_file, 'r', encoding='utf-8') as f:
            try:
                results = json.load(f)
                print(f"Loaded existing valid data for {len(results)} books.")
            except json.JSONDecodeError:
                print("Existing JSON is corrupt or empty, starting fresh.")
                results = {}
    
    for book_id, book_name, total_chapters in BIBLE_BOOKS:
        # Check if already processed
        if str(book_id) in results:
            print(f"Skipping {book_name} (Already processed)")
            continue

        # Construct directory name: e.g. "01_创世记"
        dir_name = f"{book_id:02d}_{book_name}"
        book_dir = os.path.join(audio_base_dir, dir_name)
        
        if not os.path.exists(book_dir):
            # If directory missing, we just skip without error
            continue
            
        print(f"Aligning {book_name}...")
        book_results = {}
        
        for chapter in range(1, total_chapters + 1):
            audio_path = os.path.join(book_dir, f"{chapter}.mp3")
            if not os.path.exists(audio_path):
                print(f"  Missing audio for {book_name} Chapter {chapter}")
                continue
                
            # Get text
            verses = get_verses(db_path, book_id, chapter)
            if not verses:
                print(f"  No text for {book_name} Chapter {chapter}")
                continue
                
            # Prepare text for alignment
            # Add Chapter Title as first line to align with intro audio
            chapter_title = f"{book_name} 第{chapter}章"
            text_lines = [chapter_title] + verses
            
            # Run alignment
            fragments = align_chapter(audio_path, text_lines)
            
            if fragments:
                # Process timestamps
                # Fragment 0 is title, Fragment 1 is Verse 1, etc.
                timestamps = []
                for i, frag in enumerate(fragments):
                    # Store [begin, end]
                    timestamps.append([float(frag.begin), float(frag.end)])
                
                book_results[str(chapter)] = timestamps
                print(f"  Aligned Chapter {chapter}: {len(timestamps)} segments")
            else:
                print(f"  Failed to align Chapter {chapter}")

        # Update results and save after EACH book
        results[str(book_id)] = book_results
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        print(f"Saved progress for {book_name}")
        
    print(f"Completed. Data saved to {output_file}")

if __name__ == "__main__":
    main()
