#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
pack_path="$project_root/builds/linux/siyaraj.pck"
if [[ ! -f "$pack_path" ]]; then
	printf '%s\n' 'Build the smoke PCK first with tools/smoke_build.sh.' >&2
	exit 1
fi
# Run away from the project so a successful launch must use the exported pack.
cd /tmp
exec "$godot_bin" --main-pack "$pack_path" "$@"
