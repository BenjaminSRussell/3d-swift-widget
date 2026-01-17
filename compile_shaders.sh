#!/bin/bash
set -e

mkdir -p OmniCore/Resources
AIR_FILES=""

# Use absolute path to metal if possible, or fallback
METAL_EXEC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metal"
METALLIB_EXEC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metallib"

echo "Using Metal: $METAL_EXEC"

# Compile each metal file
for file in $(find OmniCore/Shaders OmniMath/Kernels Sources/OmniGeometry/Shaders -name "*.metal"); do
    filename=$(basename "$file")
    airname="OmniCore/Resources/${filename%.*}.air"
    echo "Compiling $file..."
    "$METAL_EXEC" -c "$file" -o "$airname" -I OmniCore/Include
    AIR_FILES="$AIR_FILES $airname"
done

# Link all AIR files
echo "Linking..."
"$METALLIB_EXEC" $AIR_FILES -o OmniCore/Resources/OmniShaders.metallib

# Cleanup
rm $AIR_FILES

echo "Done!"
