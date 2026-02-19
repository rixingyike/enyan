import os
import subprocess
from concurrent.futures import ThreadPoolExecutor

SOURCE_DIR = "data/hehemp3"
TARGET_6K_DIR = "data/opus_6k"
TARGET_8K_DIR = "data/opus_8k"

# 6k Configuration (Base Level)
CMD_6K_TEMPLATE = """ffmpeg -y -i "{input_path}" -c:a libopus -b:a 6k \
    -ar 8000 -ac 1 \
    -application voip \
    -frame_duration 60 \
    -compression_level 10 \
    -dtx 1 \
    -af "highpass=f=80,silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB" \
    -map_metadata -1 -vn "{output_path}" """

# 8k Configuration (High Level)
CMD_8K_TEMPLATE = """ffmpeg -y -i "{input_path}" -c:a libopus -b:a 8k \
    -ar 16000 -ac 1 \
    -application voip \
    -frame_duration 60 \
    -compression_level 10 \
    -dtx 1 \
    -af "highpass=f=80" \
    -map_metadata -1 -vn "{output_path}" """

def transcode_file(input_path, output_path, cmd_template):
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1024:
        # print(f"Skipping {output_path} (Exists)")
        return

    # Ensure output directory exists (including subdirectories for books)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    cmd = cmd_template.format(input_path=input_path, output_path=output_path)
    
    try:
        # Run ffmpeg efficiently
        subprocess.run(cmd, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"✅ Generated: {output_path}")
    except subprocess.CalledProcessError:
        print(f"❌ Failed: {input_path}")

def main():
    tasks = []

    # Walk through the source directory
    for root, dirs, files in os.walk(SOURCE_DIR):
        for file in files:
            if file.endswith(".mp3"):
                input_path = os.path.join(root, file)
                
                # Rel path: "01_创世记/1.mp3"
                rel_path = os.path.relpath(input_path, SOURCE_DIR)
                
                # Define targets
                target_6k = os.path.join(TARGET_6K_DIR, rel_path.replace(".mp3", ".opus"))
                target_8k = os.path.join(TARGET_8K_DIR, rel_path.replace(".mp3", ".opus"))

                tasks.append((input_path, target_6k, CMD_6K_TEMPLATE))
                tasks.append((input_path, target_8k, CMD_8K_TEMPLATE))

    print(f"🚀 Starting transcoding for {len(tasks)} items...")
    
    # Use thread pool for parallel processing (FFmpeg is CPU bound but IO also matters)
    # Since FFmpeg is single-threaded per file here, running parallel helps use multi-core.
    # Adjust max_workers usually to CPU count.
    with ThreadPoolExecutor(max_workers=8) as executor:
        for input_p, output_p, cmd in tasks:
            executor.submit(transcode_file, input_p, output_p, cmd)

    print("🎉 Transcoding Done!")

if __name__ == "__main__":
    main()
