#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
mkdir -p "$project_root/builds/linux"
"$godot_bin" --headless --path "$project_root" --editor --import
"$godot_bin" --headless --path "$project_root" --export-pack 'Linux smoke test' "$project_root/builds/linux/siyaraj.pck"
