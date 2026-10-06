# Pixel-art boss versus cards

New review drafts supersede the rejected smooth comic cards. All three were approved by the user and are integrated as the first panel of their campaign boss introductions.

Open [the gallery](index.html) or [the overview](overview.png).

- [Khara PNG](khara/01.png), [native pixels](khara/01-native.png), [prompt](khara/prompt.txt).
- [Dhoomketu PNG](dhoomketu/01.png), [native pixels](dhoomketu/01-native.png), [prompt](dhoomketu/prompt.txt).
- [Swaminathan PNG](swaminathan/01.png), [native pixels](swaminathan/01-native.png), [prompt](swaminathan/prompt.txt).

Generated with `~/ml/bin/python -m ab versus` on Vertex AI / Nano Banana Pro and Flash. Metadata in each folder records the actual model and source sprites. Native cards are 320x180 with at most 64 colours; the 1920x1080 cards enlarge every pixel exactly 6x. Review gallery filtering is pixelated. Cached original model responses remain in worktree-local `out/versus/<boss>-pixel-v1/`.

Khara uses Siya, Khara and the separate gada references. Dhoomketu uses the existing design brief and Khara only as a pixel-style reference; his gameplay sprite is still pending. Swaminathan uses the complete approved ten-headed reference and head design. No smooth-comic drafts were used as references.

Validation: 22 asset-builder regression checks passed; all three pixel exports were verified for native size, palette size and exact integer enlargement. The approved cards are copied to `assets/cutscenes/boss-versus/` and shown before each campaign fight. All 30 Godot suites passed; the smoke PCK exported and launched outside the project, and packed-resource checks passed across 18 scenes. In-engine screenshots and dialogue/combat transitions are in `docs/screenshots/boss-versus/`.
