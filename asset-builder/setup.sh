#!/usr/bin/env bash
# One-time setup: Python deps in the shared ~/ml env + the Pixel Snapper binary (bin/pixel-snapper).
set -euo pipefail
cd "$(dirname "$0")"
~/ml/bin/pip install --timeout 30 --retries 10 -q pillow numpy opencv-python-headless google-genai
if [[ ! -x bin/pixel-snapper ]]; then
  command -v cargo >/dev/null || { echo "install Rust (https://rustup.rs) then rerun" >&2; exit 1; }
  cargo install --git https://github.com/Hugo-Dz/spritefusion-pixel-snapper --root /tmp/pixel-snapper
  mkdir -p bin && cp /tmp/pixel-snapper/bin/spritefusion-pixel-snapper bin/pixel-snapper
fi
~/ml/bin/python -m ab doctor
