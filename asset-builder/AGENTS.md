# asset-builder

Art generation for Siyaraj (Nano Banana on Vertex AI -> cleaned pixel art). Everything about using it
is in the skill: `skills/siyaraj-assets/SKILL.md`; read it before generating anything.

Game context in one line: playful Diwali pixel-art platformer; Siya (fireworks maker's daughter) rescues
Raj; dusk ghats -> dark forest -> festive palace; hot pink / turquoise / marigold, aubergine outlines.

Rules: run `~/ml/bin/python -m ab` from this folder (`./setup.sh` once: deps, snapper, batch bucket);
show candidates and let the user pick. Quick iterations run live (`--split pro,flash` uses both capacity
pools); big queues go through `--batch` + `ab batch submit/wait` (half price, no 429s). Never upgrade
GCP billing, raise the spend cap, buy provisioned throughput, or use AI Studio keys.
