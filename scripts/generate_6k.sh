#!/bin/bash

# Ensure we are in project root
cd "$(dirname "$0")/.."

echo "🎵 Starting 6k Opus conversion..."
python3 scripts/convert_audio_opus_low.py \
    --source data/hehemp3 \
    --output data/opus_6k

