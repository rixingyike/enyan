#!/bin/bash

# Ensure we are in project root
cd "$(dirname "$0")/.."

echo "🎵 Starting 8k Opus conversion..."
python3 scripts/batch_convert_opus.py \
    --source data/bible_assets/audio_full \
    --output data/bible_assets/8k \
    --mode 8k
