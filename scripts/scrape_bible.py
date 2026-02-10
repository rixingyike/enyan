#!/usr/bin/env python3
"""
圣经数据采集脚本
从 bible.com 抓取《新标点和合本》（神版）全部经文
"""

import json
import time
import argparse
from pathlib import Path
from playwright.sync_api import sync_playwright

# 66卷书对照表: (中文名, 英文代码, 章数)
BIBLE_BOOKS = [
    ("创世记", "GEN", 50),
    ("出埃及记", "EXO", 40),
    ("利未记", "LEV", 27),
    ("民数记", "NUM", 36),
    ("申命记", "DEU", 34),
    ("约书亚记", "JOS", 24),
    ("士师记", "JDG", 21),
    ("路得记", "RUT", 4),
    ("撒母耳记上", "1SA", 31),
    ("撒母耳记下", "2SA", 24),
    ("列王纪上", "1KI", 22),
    ("列王纪下", "2KI", 25),
    ("历代志上", "1CH", 29),
    ("历代志下", "2CH", 36),
    ("以斯拉记", "EZR", 10),
    ("尼希米记", "NEH", 13),
    ("以斯帖记", "EST", 10),
    ("约伯记", "JOB", 42),
    ("诗篇", "PSA", 150),
    ("箴言", "PRO", 31),
    ("传道书", "ECC", 12),
    ("雅歌", "SNG", 8),
    ("以赛亚书", "ISA", 66),
    ("耶利米书", "JER", 52),
    ("耶利米哀歌", "LAM", 5),
    ("以西结书", "EZK", 48),
    ("但以理书", "DAN", 12),
    ("何西阿书", "HOS", 14),
    ("约珥书", "JOL", 3),
    ("阿摩司书", "AMO", 9),
    ("俄巴底亚书", "OBA", 1),
    ("约拿书", "JNA", 4),
    ("弥迦书", "MIC", 7),
    ("那鸿书", "NAM", 3),
    ("哈巴谷书", "HAB", 3),
    ("西番雅书", "ZEP", 3),
    ("哈该书", "HAG", 2),
    ("撒迦利亚书", "ZEC", 14),
    ("玛拉基书", "MAL", 4),
    # 新约
    ("马太福音", "MAT", 28),
    ("马可福音", "MRK", 16),
    ("路加福音", "LUK", 24),
    ("约翰福音", "JHN", 21),
    ("使徒行传", "ACT", 28),
    ("罗马书", "ROM", 16),
    ("哥林多前书", "1CO", 16),
    ("哥林多后书", "2CO", 13),
    ("加拉太书", "GAL", 6),
    ("以弗所书", "EPH", 6),
    ("腓立比书", "PHP", 4),
    ("歌罗西书", "COL", 4),
    ("帖撒罗尼迦前书", "1TH", 5),
    ("帖撒罗尼迦后书", "2TH", 3),
    ("提摩太前书", "1TI", 6),
    ("提摩太后书", "2TI", 4),
    ("提多书", "TIT", 3),
    ("腓利门书", "PHM", 1),
    ("希伯来书", "HEB", 13),
    ("雅各书", "JAS", 5),
    ("彼得前书", "1PE", 5),
    ("彼得后书", "2PE", 3),
    ("约翰一书", "1JN", 5),
    ("约翰二书", "2JN", 1),
    ("约翰三书", "3JN", 1),
    ("犹大书", "JUD", 1),
    ("启示录", "REV", 22),
]

BASE_URL = "https://www.bible.com/zh-CN/bible/48/{book}.{chapter}.CUNPSS-%E7%A5%9E"


def extract_verses(page):
    """从当前页面提取所有经文"""
    return page.evaluate("""
    () => {
        const verses = [];
        // Select both labels and content spans in order of appearance
        // YouVersion uses obfuscated classes like ChapterContent_label__... and ChapterContent_content__...
        const elements = document.querySelectorAll('span[class*="ChapterContent_label"], span[class*="ChapterContent_content"]');
        
        let currentVerseNum = 0;
        let currentText = "";

        elements.forEach(el => {
            const className = el.className;
            const text = el.innerText.trim();
            
            if (className.includes("ChapterContent_label")) {
                // If we have accumulated text for a previous verse, push it
                if (currentVerseNum > 0 && currentText) {
                    verses.push({ verse: currentVerseNum, text: currentText });
                    currentText = "";
                }
                currentVerseNum = parseInt(text);
            } else if (className.includes("ChapterContent_content")) {
                // Append text (some verses are split across multiple spans)
                currentText += text;
            }
        });
        
        // Push the last verse
        if (currentVerseNum > 0 && currentText) {
            verses.push({ verse: currentVerseNum, text: currentText });
        }
        
        return verses;
    }
    """)


def scrape_chapter(page, book_code: str, chapter: int) -> list:
    """抓取单章内容"""
    url = BASE_URL.format(book=book_code, chapter=chapter)
    
    max_retries = 5
    for attempt in range(max_retries):
        try:
            # 随机延迟，模拟人类
            time.sleep(1 + (attempt * 2)) 
            page.goto(url, wait_until="domcontentloaded", timeout=60000)
            # wait networkidle separately to avoid timeout on tracking scripts
            try:
                page.wait_for_load_state("networkidle", timeout=5000)
            except:
                pass # networkidle is strict, sometimes irrelevant
            break
        except Exception as e:
            if attempt < max_retries - 1:
                wait_time = 2 ** (attempt + 1)
                print(f"⚠️ 访问失败 (尝试 {attempt+1}/{max_retries}): {e}. 等待 {wait_time}s...")
                time.sleep(wait_time)
            else:
                print(f"❌ 最终失败: {url}")
                raise e
    
    verses = extract_verses(page)
    print(f"  第 {chapter} 章: {len(verses)} 节")
    return verses


def scrape_book(browser, book_name: str, book_code: str, chapter_count: int, output_dir: Path):
    output_file = output_dir / f"{book_code}.json"
    if output_file.exists():
        print(f"⏭️ 已存在，跳过: {book_name}")
        return
        
    print(f"\n📖 正在采集: {book_name} ({book_code}) - 共 {chapter_count} 章")
    
    page = browser.new_page()
    book_data = {
        "name": book_name,
        "code": book_code,
        "chapter_count": chapter_count,
        "chapters": []
    }
    
    for ch in range(1, chapter_count + 1):
        verses = scrape_chapter(page, book_code, ch)
        book_data["chapters"].append({
            "chapter": ch,
            "verses": verses
        })
        time.sleep(0.5)  # 避免请求过快
    
    page.close()
    
    # 保存到文件
    output_file = output_dir / f"{book_code}.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(book_data, f, ensure_ascii=False, indent=2)
    
    print(f"✅ {book_name} 已保存到 {output_file}")
    return book_data


def main():
    parser = argparse.ArgumentParser(description="圣经数据采集脚本")
    parser.add_argument("--book", type=str, help="指定要采集的书卷代码 (如 MAT)")
    parser.add_argument("--all", action="store_true", help="采集全部 66 卷")
    parser.add_argument("--output", type=str, default="data/raw", help="输出目录")
    args = parser.parse_args()
    
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 确定要采集的书卷
    if args.book:
        books_to_scrape = [(n, c, ch) for n, c, ch in BIBLE_BOOKS if c == args.book.upper()]
        if not books_to_scrape:
            print(f"❌ 未找到书卷代码: {args.book}")
            return
    elif args.all:
        books_to_scrape = BIBLE_BOOKS
    else:
        # 默认只采集马太福音作为测试
        books_to_scrape = [("马太福音", "MAT", 28)]
    
    print(f"🚀 开始采集 {len(books_to_scrape)} 卷书...")
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        
        for name, code, chapters in books_to_scrape:
            scrape_book(browser, name, code, chapters, output_dir)
        
        browser.close()
    
    print("\n🎉 采集完成!")


if __name__ == "__main__":
    main()
