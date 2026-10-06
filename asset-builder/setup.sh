#!/usr/bin/env bash
# One-time setup: Python deps in the shared ~/ml env, the Pixel Snapper binary (bin/pixel-snapper) and the
# GCS bucket that Vertex batch jobs read from / write to (objects auto-delete after 7 days).
set -euo pipefail
cd "$(dirname "$0")"
~/ml/bin/pip install --timeout 30 --retries 10 -q pillow numpy opencv-python-headless google-genai
if [[ ! -x bin/pixel-snapper ]]; then
  command -v cargo >/dev/null || { echo "install Rust (https://rustup.rs) then rerun" >&2; exit 1; }
  cargo install --git https://github.com/Hugo-Dz/spritefusion-pixel-snapper --root /tmp/pixel-snapper
  mkdir -p bin && cp /tmp/pixel-snapper/bin/spritefusion-pixel-snapper bin/pixel-snapper
fi
PATH="$HOME/google-cloud-sdk/bin:$PATH"
PROJECT=project-08a2653a-a0a4-4919-a6b
BUCKET="gs://$PROJECT-ab-batch"
if ! gcloud storage buckets describe "$BUCKET" --project "$PROJECT" >/dev/null 2>&1; then
  gcloud storage buckets create "$BUCKET" --project "$PROJECT" --location us-central1 --uniform-bucket-level-access
  rule=$(mktemp) && echo '{"rule": [{"action": {"type": "Delete"}, "condition": {"age": 7}}]}' > "$rule"
  gcloud storage buckets update "$BUCKET" --lifecycle-file "$rule" && rm "$rule"
fi
~/ml/bin/python -m ab doctor
