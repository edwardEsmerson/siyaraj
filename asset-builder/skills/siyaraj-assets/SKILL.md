---
name: siyaraj-assets
description: Generate Siyaraj game art with Nano Banana on Vertex AI - new character/enemy/boss/prop sprites, animation keyframes for approved sprites, and map textures / parallax layers. Use for any sprite, keyframe, texture or background generation in asset-builder/.
---

# Siyaraj assets

Work in `asset-builder/`. Run everything with `~/ml/bin/python -m ab ...` (`-h` on any command).
Raw generations are cached in `out/`, so re-running re-cleans completed requests for free and
generates only missing raws. `--only 2,4` regenerates just those ids. Generation costs ~Rs12/image
(1K/2K Pro live), ~Rs6 (1K Pro batch), ~Rs22 (4K Pro live).

## Layout
- `sprites/<name>/` approved art: `sprite.png` (native), `meta.json` (brief, px, canvas, anchor, key),
  `<anim>/` kept keyframes. Re-snapped to the canonical scale below. `python -m ab ls` lists them. These are the style + identity source of truth.
- `refs/` inspiration images (characters/, weapons/, hud/, style/). `textures/<area>/` kept map art.
- `poses/<anim>.txt` reusable keyframe pose lists (idle, walk, run, jump, dash, attack, throw, hurt, death, fly; Siya weapons: fuljadi, rocket, chakri).
- `out/` scratch (gitignored). `ab/` the tool: `prompts.py` holds ALL prompt text, `pixel.py` cleanup.
- Boss/enemy design notes for briefs: `../docs/bosses/*.md`.

## Canonical scale (decided 2026-10-06; everything follows this)
**1 game unit = 2 art px.** Art is authored for 1080p; the game is 960x540 (`canvas_items` stretch),
so every sprite/texture goes in Godot at **scale 0.5** (pixel-perfect on 1080p+ screens). Sprite size
= the subject's longest side, derived from its collider, set with `--role` (code: `ROLES` in `ab/__main__.py`):

| role | art px | game units | used for |
| --- | --- | --- | --- |
| hero | 80 | 40 | Siya (collider 24x40), Raj, Swaminathan |
| enemy | 88 | 44 | basic rakshas / ground shooter (32x40) |
| brute | 136 | 68 | brute (48x64) |
| flyer | 80 | 40 | winged demon (32x28 + wings), approved Robin smaller (`--height 48`) |
| boss | 200 | 100 | Khara (56x92) |
| big-boss | 280 | 140 | Ravan (100x60 body + heads) |
| prop | 40 | 20 | weapons, thrown fireworks |
| pickup | 24 | 12 | collectibles, small projectiles (radius 5) |

Tiles: 128 art px (64 units). Parallax layers: 1080 art px tall (full screen), drawn at 2 art px per
pixel (`--chunk 2`). Canvases are square, 1.5x the subject, so poses have room; feet sit on the anchor.

## Cast notes (from the proposal)
- Siya: hero, lean and graceful, visible hands (sparkler whip, rocket dash). Approved: `sprites/siya`.
- Raj: dramatic captive / comic foil, clean-shaven, expressive poses.
- Swaminathan: villain, big twirlable moustache; angrier phase after it is burned.
- Robin: small bird companion (later hypnotised eyes, dizzy fall). Bosses: Khara, Ravan (`../docs/bosses/`).
- Guards: reuse base shapes with palette swaps rather than new designs. No baked glow on characters;
  firework light/sparks are separate effect sprites. Reference photos guide shape only (copyrighted).

## 1. New sprite (character, enemy, boss, prop)
```bash
python -m ab sprite ravan "Ravan, ten-headed rakshasa king boss: ..." -r refs/characters/trishiras-three-headed-rakshasa.jpg --size 4K --style siya basic-rakshas
python -m ab pick ravan 03            # after the user chooses from out/ravan/sheet.png
```
- 4 candidates by default (`-n`). Show the user `out/<name>/sheet.png` and **let them choose**.
- `--style` = approved sprites to match pixel style (default `siya`; they never define identity).
  `-r` = design references for the new subject (photos/paintings are fine).
- Always pass the right `--role` (see the table); `--height N` overrides. Above 150px it generates at 4K
  automatically in live mode. Flyers/props/projectiles: `--anchor center`.
- `--view right-profile|front-three-quarter|front` and
  `--subject full-body|head|headless-body|prop` set composition. Defaults retain the existing
  full-body right profile. Animation prompts preserve the approved base's choices.
- `--batch` resolves to 1K before preparing prompts/references; explicit 2K/4K batches are
  rejected. Queue with `--batch`, then `ab batch submit`, `status`, and `fetch`. Do not change
  a prepared queue's resolution. Live boss bodies remain 4K.
- `--key magenta` (or blue) if the subject is green; the key must not appear on the subject.
- Brief: role, silhouette, build, face/hair, outfit colours, prop + which hand, relative size. Keep it
  concrete and short; style/background/framing text is added automatically.

## 2. Keyframes for an approved sprite
```bash
python -m ab frames siya run                       # uses poses/run.txt
python -m ab frames siya cheer "arms raised, jumping with joy" "landing, grinning"
python -m ab keep siya run                         # -> sprites/siya/run/ (frames, strip.png, preview.gif)
```
- One request per pose, each conditioned on the approved sprite; colours are locked to the sprite's
  palette (`--free-palette` for effects like sparks). Frames are registered on the sprite's anchor (feet,
  or body centre for flyers), so jumps/bobs are added in-engine.
- Review `out/<name>/<anim>/sheet.png` + `preview.gif`; regenerate bad poses with `--only`.
- These are keyframes: 2-5 strong poses per action. Write poses as concrete body positions (limbs,
  weight, facing), not feelings. Add a reusable list to `poses/` when a new action repeats across sprites.
- `--fps`, `--loop loop|once|hold|none`, and `--durations` (one positive duration in 1/FPS units
  per frame) preserve timing in metadata and GIFs. Expanded poses share padding around the anchor;
  no individual frame is resized. `keep` refuses incomplete frame sequences.

## Cast production and packaging

`cast_manifest.json` is the tracked character plan: seven new bases, 73 sets / 195 frames,
including Robin's existing fly/perch. Swaminathan's headless body is 260px and his separate
head is 76px; Khara is 200px and his separate gada is 120px. See
`../docs/art/character_library.md` for generation, attachment registration and F6 preview.

`ab cast prepare --base` or `--wave movement|combat|story` prints the existing sprite/frames
commands; `--execute` runs them. Review candidates with `ab cast review`, then let the user
choose before `pick`. Review wave sheets/GIFs before `keep`. `ab cast export` packages only
approved sources. `--complete` validates the entire requested library, including hand/pivot
registration. Finish a successful fetched 1K pilot before expanding the animation queue.

Scratch outputs and batch records remain worktree-local. Cloud jobs have unique prefixes.
Re-running `batch submit` resumes unsent model lanes, and `batch fetch` retries downloads
without discarding completed raws or treating missing rows as rejected images.

`ab cast import-sheet` imports a generated transparent sheet using one fixed source
camera grid. A neutral `--calibration-cell` establishes scale once for the whole sheet;
`--start-cell` skips it in the animation output. Connected extraction preserves limbs
across mathematical cell borders. Reviewed `--effect-owner SOURCE:DESTINATION` values
attach detached effects to their intended actor. Review sheets/GIFs before `keep`.
Record every Khara hand using `ab cast attach`; `--hide` marks actions with busy hands.
Actual source models/grid metadata remain separate from preferred generation settings.

## 3. Map textures and parallax layers
```bash
python -m ab texture ghat-stone "worn sandstone ghat steps, ..." --mode tile --tile 128
python -m ab texture forest-far "dusk forest silhouettes, ..." --mode layer --aspect 21:9    # opaque, 1080px tall
python -m ab texture forest-near "hanging vines and roots" --mode cutout                    # transparent shapes
cp out/textures/forest-far/01.png textures/forest/forest-far.png
```
- Modes: `tile` seamless square fill (128 art px = 64 units); `cap` transparent strip along a platform's
  top edge, full-width seamless, `--cap-height` art px tall (default 32), the walking surface a third of
  the way down; `concept` a 16:9 mock level screen for choosing art direction (not used in game);
  `layer` opaque parallax; `cutout` parallax shapes with transparency; `panel` one complete opaque 16:9
  comic illustration (no speech bubbles or lettering; pass approved characters with repeated `-r` flags).
  Panel candidates are written to `out/panels/<name>/`; review `sheet.png` and let the user choose.
- **Terrain scale:** most platforms are thin 32-unit (64 art px) slabs, so a fill shows barely half a
  tile; **caps and fringes carry most of the look**. Spend iterations there; keep fills calm.
- Check `sheet.png` / `NN-tiled.png` for seams before keeping. `ab blend A B` builds a transition tile
  in code (no generation; `--seed N` for another boundary). `ab board [area]` composes the kept
  `textures/<area>/` fills (`*-cap.png` as caps, `A__B.png` as transitions) into a mock side view.
- Viewport is 960x540 game units = 1920x1080 art px. Existing forest layers: `textures/forest/j1-j4.png`.

**World kits in Godot:** `scripts/levels/world_skin.gd` (`WorldSkin` node in each level, `biome` + `direction`)
dresses the grey Body/Edge platforms from `assets/world/<biome>/<direction>/` at scale 0.5. Every file is optional:
`fill.png` (128 px seamless tile), `cap.png` (seamless strip, walking surface a third down), `end.png` (left end,
mirrored for the right), `fringe.png` (hangs under floating platforms), `oneway.png` (strip centred on thin
jump-through platforms), `far.png` (opaque) / `mid.png` (transparent) 1080 px tall seamless parallax, `water.png`
(river tile, from just above the `RiverLine` to the bottom) and `props/*.png` (stand on the bottom of their opaque
pixels). `setpieces.png` (512 px sheet of separate pieces on transparency) is cut into its connected pieces at load:
pieces 96+ px tall become landmarks, drawn at twice prop scale on wide ground behind the actors (seeded, spaced,
clear of diyas/doors/finish, every piece before repeats); smaller ones join the props. `back.png` (128 px tile) is the
back wall: under roofs/balconies/galleries (recesses), over side-room `Backdrop`s and inside portal `Door`s (framed
in fill). `arena.png` (1934x1080 one-screen scene) is the boss arena backdrop: the Khara (forest) and Ravan (palace)
arenas have a `WorldSkin` with `arena = true`, which follows the direction the level last showed. New PNGs load
straight from disk; run `godot --headless --path . --import` once before exporting. In game, `V` cycles the
available kits; `tests/world_skin_check.gd` checks every kit dresses fully without moving collision geometry.
Screenshot every level x kit at 5 spots plus the arena (from the repo root; in a fresh worktree import once first),
then build contact sheets:
```bash
xvfb-run -a godot --path . --resolution 1920x1080 -s tools/world_shots.gd [-- <biome> [<direction> | <kit dir>]]
~/ml/bin/python tools/world_sheet.py    # docs/screenshots/world/<biome>-sheet.png
```

## 4. UI art
```bash
python -m ab ui panel "carved marigold wood frame with brass corners" --kind frame   # 9-slice
python -m ab ui heart "pink diya heart" --kind icon --px 16
```
UI is drawn at 1 texel = 1 game unit (used at scale 1, unlike sprites). Frames are mirrored to
symmetric corners and cut to `NN-nine.png` for a StyleBoxTexture (`texture_margin` per candidate in
`margins.json`, axis stretch TILE_FIT); copy the pick to `../assets/ui/`.

## Problems the tool flags (`!!` in output, `!` on sheets)
It auto-regenerates once (`--retry`). Background removal measures the real border colour, so off-colour
flat backgrounds (muted green, grey, white) are handled; what it can't fix and flags:
- fake checkerboard / scene bleed -> regenerate (`--only N`); usually caused by a photo `-r` - try fewer refs.
- art touching the edge -> clipped; regenerate.
- size drift on frames -> fine for crouch/stretch poses, otherwise regenerate.

## Rate limits (429 RESOURCE_EXHAUSTED)
Pro image models on Vertex use Dynamic Shared Quota: 429 means Google's shared pool is busy, not a
per-project cap, so extra keys/projects don't help. The tool backs off and retries automatically
(up to ~5 min). If it persists: `--jobs 1`, or `--fallback flash` (separate capacity, slightly lower
quality), or try later. Never upgrade billing or use AI Studio keys (trial credits cover Vertex only).
Spend is capped by `~/nanobanana/gen.py` (ledger `~/nanobanana/spend.json`); `python -m ab doctor` shows it.

## Using art in the game
Copy chosen PNGs into the Godot project (e.g. `assets/sprites/<name>/`); asset-builder has a
`.gdignore`, so Godot never imports it. Use them at **scale 0.5** with the sprite's `anchor` as the
origin offset (feet on the collider bottom). The project already uses nearest filtering.
