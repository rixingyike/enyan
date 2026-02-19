#!/bin/bash

# reset_downloads.sh
# Deletes downloaded resource packs for testing purposes.

echo "🗑️  Deleting downloaded resources..."

# Potential locations for 'packs' directory
LOCATIONS=(
    "$HOME/Documents/packs"
    "$HOME/Library/Containers/com.yishulun.enyan/Data/Documents/packs"
    "$HOME/Library/Application Support/com.yishulun.enyan/packs"
)

FOUND=0

for DIR in "${LOCATIONS[@]}"; do
    if [ -d "$DIR" ]; then
        echo "🔥 Deleting: $DIR"
        rm -rf "$DIR"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "⚠️  No 'packs' directory found in common locations."
    echo "   Checked:"
    for DIR in "${LOCATIONS[@]}"; do
        echo "   - $DIR"
    done
else
    echo "✅ Resource packs deleted."
    echo "   Please restart the app to reflect changes."
fi
