#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
byte_rush_godot="${BYTE_RUSH_GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
output_dir="$project_dir/build"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This build helper requires macOS for app signing.' >&2
  exit 1
fi
if [[ ! -x "$byte_rush_godot" ]]; then
  echo 'Set BYTE_RUSH_GODOT to the Godot 4.5.1 executable, or install Godot.app in /Applications.' >&2
  exit 1
fi
mkdir -p "$output_dir"
touch "$output_dir/.gdignore"
"$byte_rush_godot" --headless --path "$project_dir" --import
"$byte_rush_godot" --headless --path "$project_dir" --export-release macOS "$output_dir/Byte Rush.app"
/usr/bin/codesign --verify --deep --strict "$output_dir/Byte Rush.app"
echo 'Built build/Byte Rush.app and verified its signature.'
