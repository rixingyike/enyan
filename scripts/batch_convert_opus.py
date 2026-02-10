import os
import subprocess
import argparse
import time

def convert_audio(source_dir, output_dir, mode='6k'):
    if mode == '6k':
        # 6k settings
        cmd_template = [
            "ffmpeg", "-n", "-i", "{input}", 
            "-c:a", "libopus", "-b:a", "6k",
            "-ar", "8000", "-ac", "1",
            "-application", "voip",
            "-frame_duration", "60",
            "-compression_level", "10",
            "-dtx", "1",
            "-af", "highpass=f=80,silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB",
            "-map_metadata", "-1", "-vn", "{output}"
        ]
    else:
        # 8k settings
        cmd_template = [
            "ffmpeg", "-n", "-i", "{input}", 
            "-c:a", "libopus", "-b:a", "8k",
            "-ar", "16000", "-ac", "1",
            "-application", "voip",
            "-frame_duration", "60",
            "-compression_level", "10",
            "-dtx", "1",
            "-af", "highpass=f=80",
            "-map_metadata", "-1", "-vn", "{output}"
        ]

    abs_source = os.path.abspath(source_dir)
    abs_output = os.path.abspath(output_dir)

    print(f"🚀 Starting conversion: {mode}")
    print(f"📂 Source: {abs_source}")
    print(f"📂 Output: {abs_output}")

    total_files = 0
    converted_files = 0
    skipped_files = 0
    failed_files = 0

    for root, dirs, files in os.walk(abs_source):
        # Create corresponding directory structure in output
        rel_path = os.path.relpath(root, abs_source)
        target_dir = os.path.join(abs_output, rel_path)
        
        if not os.path.exists(target_dir):
            os.makedirs(target_dir)

        for file in files:
            if not file.lower().endswith('.mp3'):
                continue
            
            total_files += 1
            input_path = os.path.join(root, file)
            
            # Construct output filename (change extension to .opus)
            output_filename = os.path.splitext(file)[0] + ".opus"
            output_path = os.path.join(target_dir, output_filename)

            if os.path.exists(output_path):
                # print(f"⏭️  Skipping existing: {output_filename}")
                skipped_files += 1
                continue

            print(f"Processing ({total_files}): {rel_path}/{file} -> {output_filename}")
            
            # Prepare command
            cmd = [arg.format(input=input_path, output=output_path) for arg in cmd_template]
            
            try:
                # Run ffmpeg, suppress verbosity but show errors
                # -n flag in template prevents overwriting, but we already checked existence
                result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                
                if result.returncode == 0:
                    converted_files += 1
                else:
                    print(f"❌ Error converting {file}: {result.stderr.strip()}")
                    failed_files += 1
            except Exception as e:
                print(f"❌ Exception converting {file}: {e}")
                failed_files += 1

    print("\n🎉 Conversion finished!")
    print(f"📊 Total: {total_files}")
    print(f"✅ Converted: {converted_files}")
    print(f"⏭️  Skipped: {skipped_files}")
    print(f"❌ Failed: {failed_files}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Batch convert audio to Opus")
    parser.add_argument("--source", required=True, help="Source directory")
    parser.add_argument("--output", required=True, help="Output directory")
    parser.add_argument("--mode", choices=['6k', '8k'], required=True, help="Conversion mode (6k or 8k)")
    
    args = parser.parse_args()
    
    convert_audio(args.source, args.output, args.mode)
