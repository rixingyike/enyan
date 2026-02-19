import json
import os
from pathlib import Path

def merge_bible_files(input_dir: str, output_file: str):
    """Merge individual book JSONs into one list"""
    input_path = Path(input_dir)
    books = []
    
    # Order matters. We need to follow the standard 66 books order.
    # The filenames are CODE.json. We can use the list from scrape_bible.py or just trust the files if we map them.
    # Better to iterate through the known order.
    
    BIBLE_ORDER = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JNA", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
        "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"
    ]
    
    print(f"Merging files from {input_dir}...")
    
    for code in BIBLE_ORDER:
        file_path = input_path / f"{code}.json"
        if file_path.exists():
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                # Ensure data structure fits build_db.py expectation
                # build_db.py expects: {"name": ..., "chapters": ...}
                # scrape_bible.py outputs exactly that.
                books.append(data)
                print(f"Loaded {code}")
        else:
             print(f"Warning: {code}.json not found in {input_dir}")
             
    print(f"Total books loaded: {len(books)}")
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(books, f, ensure_ascii=False, indent=2)
    print(f"Saved merged file to {output_file}")

if __name__ == "__main__":
    merge_bible_files("data/raw_chs", "data/bible_assets/cunpss_bible_text.json")
