#!/bin/bash

# Ensure we are in project root
cd "$(dirname "$0")/.."

echo "🎵 Starting 6k Opus conversion..."
python3 scripts/batch_convert_opus.py \
    --source data/bible_assets/audio_full \
    --output data/bible_assets/6k \
    --mode 6k
