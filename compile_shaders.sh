#!/bin/bash
# Validate every Metal shader under Sources/ by compiling it to AIR.
# SwiftPM compiles each target's .metal resources into its own default.metallib at build time;
# this script exists to surface per-file shader errors clearly in CI.
# Compatible with macOS's bash 3.2 (no mapfile/readarray).
set -u

OUT="${SHADER_OUT_DIR:-.build/shader-check}"
mkdir -p "$OUT"

METAL="$(xcrun -f metal 2>/dev/null || true)"
if [ -z "$METAL" ]; then
  echo "::error::metal compiler not found (xcrun -f metal). Install Xcode / the Metal toolchain." >&2
  exit 1
fi
echo "Using Metal: $METAL"

count=0
failed=0
while IFS= read -r -d '' file; do
  count=$((count + 1))
  safe=$(printf '%s' "$file" | tr '/ ' '__')
  air="$OUT/${safe%.metal}.air"
  if "$METAL" -c "$file" -o "$air" -I Sources/OmniCore/Include -I "$(dirname "$file")" 2>"$air.log"; then
    echo "ok    $file"
  else
    failed=$((failed + 1))
    echo "FAIL  $file"
    sed 's/^/      /' "$air.log"
    echo "::error file=$file::Metal shader failed to compile"
  fi
done < <(find Sources -name '*.metal' -print0 | sort -z)

if [ "$count" -eq 0 ]; then
  echo "::error::No .metal files found under Sources/" >&2
  exit 1
fi
echo "Compiled $((count - failed))/$count shaders"
[ "$failed" -eq 0 ]
