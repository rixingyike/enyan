#!/bin/bash

# Ensure we are in project root
cd "$(dirname "$0")/.."

echo "🎵 Starting 8k Opus conversion..."
python3 scripts/batch_convert_opus.py \
    --source data/hehemp3 \
    --output data/opus_8k \
    --mode 8k
