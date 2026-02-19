import os
import shutil
import gzip
import zipfile

# Configuration
SOURCE_CHT_DIR = "assets/cht"
SOURCE_OPUS_6K = "data/opus_6k"
SOURCE_OPUS_8K = "data/opus_8k"

TARGET_DIR = "server/packs"

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def compress_file_gzip(src_path, dst_path):
    print(f"📦 Compressing {src_path} -> {dst_path} ...")
    with open(src_path, 'rb') as f_in:
        with gzip.open(dst_path, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)
    print(f"✅ Done: {dst_path}")

def zip_folder(folder_path, zip_path):
    print(f"🤐 Zipping {folder_path} -> {zip_path} ...")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                if file.startswith('.'): continue # Skip .DS_Store
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, folder_path)
                zipf.write(file_path, arcname)
    print(f"✅ Zipped: {zip_path}")

def pack_folder_gzip(folder_path, target_gz_path):
    # Temp zip
    temp_zip = folder_path.rstrip('/') + ".temp.zip"
    zip_folder(folder_path, temp_zip)
    
    # Compress zip to gz
    compress_file_gzip(temp_zip, target_gz_path)
    
    # Cleanup
    os.remove(temp_zip)

def main():
    ensure_dir(TARGET_DIR)

    # 1. Pack CHT Resources (DB + Font)
    if os.path.exists(SOURCE_CHT_DIR):
        target_cht_gz = os.path.join(TARGET_DIR, "lang_cht.zip.gz")
        pack_folder_gzip(SOURCE_CHT_DIR, target_cht_gz)
    else:
        print(f"⚠️ Warning: {SOURCE_CHT_DIR} not found.")

    # 2. Pack Opus 6k
    if os.path.exists(SOURCE_OPUS_6K):
        target_6k_gz = os.path.join(TARGET_DIR, "voice_6k.zip.gz")
        pack_folder_gzip(SOURCE_OPUS_6K, target_6k_gz)
    else:
        print(f"⚠️ Warning: {SOURCE_OPUS_6K} not found.")

    # 3. Pack Opus 8k
    if os.path.exists(SOURCE_OPUS_8K):
        target_8k_gz = os.path.join(TARGET_DIR, "voice_8k.zip.gz")
        pack_folder_gzip(SOURCE_OPUS_8K, target_8k_gz)
    else:
        print(f"⚠️ Warning: {SOURCE_OPUS_8K} not found.")

if __name__ == "__main__":
    main()
