
import os
import sqlite3
import json
from aeneas.executetask import ExecuteTask
from aeneas.task import Task

def align_chapter(audio_path, text_lines):
    temp_text_path = "temp_fail_test.txt"
    with open(temp_text_path, "w", encoding="utf-8") as f:
        for line in text_lines:
            f.write(line + "\n")

    config_string = "task_language=cmn|is_text_type=plain|os_task_file_format=json"
    task = Task(config_string=config_string)
    task.audio_file_path_absolute = os.path.abspath(audio_path)
    task.text_file_path_absolute = os.path.abspath(temp_text_path)

    try:
        ExecuteTask(task).execute()
        return True
    except Exception as e:
        print(f"Error during alignment: {e}")
        import traceback
        traceback.print_exc()
        return False

db_path = "assets/chs/bible_chs.db"
audio_path = "data/hehemp3/05_申命记/5.mp3"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("SELECT text FROM verses WHERE book_id=5 AND chapter=5 ORDER BY verse")
verses = [r[0] for r in cursor.fetchall()]
conn.close()

text_lines = ["申命记 第5章"] + verses
print(f"Verses count: {len(verses)}")

align_chapter(audio_path, text_lines)
