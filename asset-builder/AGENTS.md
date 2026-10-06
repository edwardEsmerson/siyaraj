# asset-builder

Art generation for Siyaraj (Nano Banana on Vertex AI -> cleaned pixel art). Everything about using it
is in the skill: `skills/siyaraj-assets/SKILL.md`; read it before generating anything.

Game context in one line: playful Diwali pixel-art platformer; Siya (fireworks maker's daughter) rescues
Raj; dusk ghats -> dark forest -> festive palace; hot pink / turquoise / marigold, aubergine outlines.

Rules: run `~/ml/bin/python -m ab` from this folder; show candidates and let the user pick; never
upgrade GCP billing, raise the spend cap, or use AI Studio keys.

Character production uses `cast_manifest.json` and `ab cast prepare/review/validate/export`.
Batch image requests must be prepared at 1K; live large boss bodies use 4K. Keep scratch,
queue and job records local to the worktree. See `../docs/art/character_library.md`.
