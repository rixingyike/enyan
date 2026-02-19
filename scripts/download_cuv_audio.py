import os
import requests
from concurrent.futures import ThreadPoolExecutor
import time

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

BASE_URL = "http://audio2.abiblica.org/bibles/app/audio/4/{book}/{chapter}.mp3"
SAVE_DIR = "data/hehemp3"

def download_chapter(book_id, book_name, chapter):
    book_dir = os.path.join(SAVE_DIR, f"{book_id:02}_{book_name}")
    if not os.path.exists(book_dir):
        os.makedirs(book_dir, exist_ok=True)
    
    file_path = os.path.join(book_dir, f"{chapter}.mp3")
    
    if os.path.exists(file_path) and os.path.getsize(file_path) > 1024:
        print(f"Skipping {book_name} Ch {chapter} (Exists)")
        return
    
    url = BASE_URL.format(book=book_id, chapter=chapter)
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    retries = 5
    for i in range(retries):
        try:
            print(f"Downloading {book_name} Ch {chapter} ({url})...")
            response = requests.get(url, headers=headers, timeout=45, stream=True)
            if response.status_code == 200:
                with open(file_path, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=16384):
                        f.write(chunk)
                
                # Double check size (CUV chapters usually > 50kb)
                if os.path.getsize(file_path) < 1024:
                    print(f"⚠️ Warning: File too small for {book_name} Ch {chapter}")
                    continue
                    
                print(f"✅ Success: {book_name} Ch {chapter}")
                return
            else:
                print(f"❌ Failed: {book_name} Ch {chapter} (Status {response.status_code})")
        except Exception as e:
            print(f"⚠️ Error: {book_name} Ch {chapter} (Retry {i+1}/{retries}): {e}")
            time.sleep(5)
    
    print(f"💥 Failed after {retries} retries: {book_name} Ch {chapter}")

def main():
    if not os.path.exists(SAVE_DIR):
        os.makedirs(SAVE_DIR)
    
    tasks = []
    for book_id, book_name, chapter_count in BIBLE_BOOKS:
        for chapter in range(1, chapter_count + 1):
            tasks.append((book_id, book_name, chapter))
    
    print(f"🚀 Starting download of {len(tasks)} chapters (Resuming if exists)...")
    
    # Lower concurrency to avoid triggering server rate limits (Ultra-conservative)
    with ThreadPoolExecutor(max_workers=2) as executor:
        for book_id, book_name, chapter in tasks:
            executor.submit(download_chapter, book_id, book_name, chapter)

if __name__ == "__main__":
    main()
