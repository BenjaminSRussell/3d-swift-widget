#!/bin/bash
set -e

# Project OMNI Shader Compiler
# Compiles all .metal files in OmniCore/Shaders/Render and OmniCore/Shaders/Compute
# directly into a metallib.

# SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
METAL_FLAGS="-std=macos-metal2.4 -I OmniCore/Include" 
# Fallback to macos for now to verify metal availability on host


OUTPUT_DIR="OmniCore/Resources"
mkdir -p "$OUTPUT_DIR"

echo "🔮 Compiling Shaders..."

# Find all metal files
find OmniCore/Shaders -name "*.metal" | while read -r file; do
    filename=$(basename -- "$file")
    name="${filename%.*}"
    air_file="$OUTPUT_DIR/$name.air"
    
    echo "   Compiling $filename..."
    xcrun -sdk iphoneos metal $METAL_FLAGS -c "$file" -o "$air_file"
done

# Link into metallib
echo "🔗 Linking Shaders..."
xcrun -sdk iphoneos metallib "$OUTPUT_DIR"/*.air -o "$OUTPUT_DIR/OmniShaders.metallib"

# Cleanup AIR files
rm "$OUTPUT_DIR"/*.air

echo "✅ Shader Compilation Complete: $OUTPUT_DIR/OmniShaders.metallib"
