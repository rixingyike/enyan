                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        #!/bin/bash
# Wrapper to run Piper with correct library paths on macOS
# Usage: ./run_piper.sh --model <model> --input_file <input> --output_file <output>

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# The piper executable is inside the extracted 'piper' directory
PIPER_DIR="$SCRIPT_DIR/piper"

# Set library path to include the piper directory where dylibs reside
export DYLD_LIBRARY_PATH="$PIPER_DIR"

# Run piper
"$PIPER_DIR/piper" "$@"
