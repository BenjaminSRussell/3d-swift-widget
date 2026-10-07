#!/bin/bash
set -e

mkdir -p OmniCore/Resources
AIR_FILES=""

# Use absolute path to metal if possible, or fallback
if [ -x "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metal" ]; then
  METAL_EXEC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metal"
  METALLIB_EXEC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/metallib"
else
  METAL_EXEC="$(xcrun -f metal)"
  METALLIB_EXEC="$(xcrun -f metallib)"
fi

echo "Using Metal: $METAL_EXEC"
# Fail clearly when no shaders found
shopt -s nullglob
METAL_FILES=(OmniCore/Shaders/*.metal OmniMath/Kernels/*.metal Sources/OmniGeometry/Shaders/*.metal)
if [ ${#METAL_FILES[@]} -eq 0 ]; then
  # Also search recursively under Sources
  mapfile -t METAL_FILES < <(find Sources OmniCore OmniMath -name '*.metal' 2>/dev/null || true)
fi
if [ ${#METAL_FILES[@]} -eq 0 ]; then
  echo "No .metal files found" >&2
  exit 1
fi

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
