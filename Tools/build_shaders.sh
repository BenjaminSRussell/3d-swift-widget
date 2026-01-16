#!/bin/bash
set -e

# Project OMNI Shader Compiler
# Compiles all .metal files in OmniCore/Shaders/Render and OmniCore/Shaders/Compute
# directly into a metallib.

# Find toolchain path
TOOLCHAIN_PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
METAL_TOOL="$TOOLCHAIN_PATH/metal"
METALLIB_TOOL="$TOOLCHAIN_PATH/metallib"

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
METAL_FLAGS="-std=macos-metal3.0 -I OmniCore/Include -isysroot $SDK_PATH"

OUTPUT_DIR="OmniCore/Resources"
mkdir -p "$OUTPUT_DIR"

echo "🔮 Compiling Shaders using $METAL_TOOL..."

# Find all metal files
find OmniCore/Shaders -name "*.metal" | while read -r file; do
    filename=$(basename -- "$file")
    name="${filename%.*}"
    air_file="$OUTPUT_DIR/$name.air"
    
    echo "   Compiling $filename..."
    "$METAL_TOOL" $METAL_FLAGS -c "$file" -o "$air_file"
done

# Link into metallib
echo "🔗 Linking Shaders using $METALLIB_TOOL..."
"$METALLIB_TOOL" "$OUTPUT_DIR"/*.air -o "$OUTPUT_DIR/OmniShaders.metallib"

# Cleanup AIR files
rm "$OUTPUT_DIR"/*.air

echo "✅ Shader Compilation Complete: $OUTPUT_DIR/OmniShaders.metallib"
