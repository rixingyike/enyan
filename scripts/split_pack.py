import os
import sys

def split_file(file_path, num_parts):
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' not found.")
        return

    file_size = os.path.getsize(file_path)
    part_size = file_size // num_parts
    remainder = file_size % num_parts

    print(f"Splitting '{file_path}' ({file_size} bytes) into {num_parts} parts...")

    with open(file_path, 'rb') as f:
        for i in range(num_parts):
            # Last part gets the remainder
            current_part_size = part_size + (remainder if i == num_parts - 1 else 0)
            
            # 1-based index (part1, part2...)
            part_filename = f"{file_path}.part{i + 1}"
            
            print(f"  Writing {part_filename} ({current_part_size} bytes)...")
            
            with open(part_filename, 'wb') as part_file:
                chunk_size = 1024 * 1024 # 1MB buffer
                bytes_written = 0
                while bytes_written < current_part_size:
                    read_size = min(chunk_size, current_part_size - bytes_written)
                    data = f.read(read_size)
                    if not data:
                        break
                    part_file.write(data)
                    bytes_written += len(data)
            
    print("Done.")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python split_pack.py <file_path> <num_parts>")
        sys.exit(1)

    file_path = sys.argv[1]
    try:
        num_parts = int(sys.argv[2])
    except ValueError:
        print("Error: number of parts must be an integer.")
        sys.exit(1)

    split_file(file_path, num_parts)
