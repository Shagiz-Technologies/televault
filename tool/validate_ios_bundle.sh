#!/usr/bin/env bash

set -euo pipefail

app="${1:?Usage: validate_ios_bundle.sh <Runner.app>}"
if [[ ! -d "$app" || ! -f "$app/Runner" ]]; then
  echo "Invalid iOS app bundle: $app" >&2
  exit 1
fi

dependencies_file="$(mktemp)"
symbols_file="$(mktemp)"
trap 'rm -f "$dependencies_file" "$symbols_file"' EXIT

binaries=("$app/Runner")
for framework in "$app"/Frameworks/*.framework; do
  binary="$framework/$(basename "$framework" .framework)"
  if [[ -f "$binary" ]]; then
    binaries+=("$binary")
  fi
done

for binary in "${binaries[@]}"; do
  /usr/bin/otool -L "$binary" |
    /usr/bin/awk '$1 ~ /^@rpath\// { print $1 }' >> "$dependencies_file"
  /usr/bin/nm -gU "$binary" >> "$symbols_file" 2>/dev/null || true
done

/usr/bin/sort -u -o "$dependencies_file" "$dependencies_file"

missing=0
while IFS= read -r dependency; do
  [[ -z "$dependency" ]] && continue
  relative_path="${dependency#@rpath/}"
  if [[ ! -e "$app/Frameworks/$relative_path" && ! -e "$app/$relative_path" ]]; then
    echo "Missing bundled dependency: $dependency" >&2
    missing=1
  fi
done < "$dependencies_file"

if /usr/bin/grep -q '^@rpath/libtdjson\.dylib$' "$dependencies_file"; then
  echo 'TDLib is dynamically linked as a standalone dylib; use the static iOS XCFramework.' >&2
  missing=1
fi

if ! /usr/bin/grep -Eq '[[:space:]]_td_create_client_id$' "$symbols_file"; then
  echo 'TDLib FFI symbols are missing from the iOS app binaries.' >&2
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "Validated native dependencies and TDLib FFI symbols in $app"
