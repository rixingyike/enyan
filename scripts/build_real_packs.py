import os
import zipfile

# 配置路径
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'packs')

# 资源源路径
# 1. 繁体数据库 (位于 assets/bible_cht.db)
CHT_DB_PATH = os.path.join(PROJECT_ROOT, 'assets', 'bible_cht.db')

# 2. 6k 语音包 (data/bible_assets/6k)
VOICE_6K_DIR = os.path.join(PROJECT_ROOT, 'data', 'bible_assets', '6k')

# 3. 8k 语音包 (data/bible_assets/8k)
VOICE_8K_DIR = os.path.join(PROJECT_ROOT, 'data', 'bible_assets', '8k')

def create_zip(source, output_filename):
    output_path = os.path.join(PACKS_DIR, output_filename)
    print(f"📦 Packaging {output_filename}...")
    
    if not os.path.exists(source):
        print(f"⚠️  Source not found: {source}")
        dummy_content = f"Placeholder for {output_filename}. Source {source} missing."
        with zipfile.ZipFile(output_path, 'w') as zipf:
            zipf.writestr('README.txt', dummy_content)
        print(f"⚠️  Created placeholder pack.")
        return

    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        if os.path.isfile(source):
            zipf.write(source, os.path.basename(source))
            print(f"   Added 1 file.")
        else:
            count = 0
            for root, dirs, files in os.walk(source):
                for file in files:
                    if file.startswith('.'): continue
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, source)
                    zipf.write(file_path, arcname)
                    count += 1
            print(f"   Added {count} files.")
            
    size_mb = os.path.getsize(output_path) / 1024 / 1024
    print(f"✅ Created {output_path} ({size_mb:.2f} MB)")

if __name__ == "__main__":
    if not os.path.exists(PACKS_DIR):
        os.makedirs(PACKS_DIR)

    print("🚀 Building packs...")
    
    create_zip(CHT_DB_PATH, 'lang_cht.zip')
    create_zip(VOICE_6K_DIR, 'voice_6k.zip')
    create_zip(VOICE_8K_DIR, 'voice_8k.zip')
    
    print("\n🎉 All packs built in scripts/packs/")
