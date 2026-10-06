---
name: siyaraj-assets
description: Generate Siyaraj game art with Nano Banana on Vertex AI - new character/enemy/boss/prop sprites, animation keyframes for approved sprites, map textures (fills, caps, transitions, concepts), parallax layers and UI art, live or via cheaper Vertex batch jobs. Use for any sprite, keyframe, texture, background or UI generation in asset-builder/.
---

# Siyaraj assets

Work in `asset-builder/`. Run everything with `~/ml/bin/python -m ab ...` (`-h` on any command).
Every command is idempotent: raw generations are cached in `out/`, so re-running only re-cleans
(free). `--only 2,4` regenerates just those ids. Live prices per image: pro ~Rs12 (1K/2K), ~Rs22 (4K);
flash ~Rs6 (1K), ~Rs9 (2K), ~Rs14 (4K). Batch (`--batch`) is half that.

## Layout
- `sprites/<name>/` approved art: `sprite.png` (native), `meta.json` (brief, px, canvas, anchor, key),
  `<anim>/` kept keyframes. Re-snapped to the canonical scale below. `python -m ab ls` lists them. These are the style + identity source of truth.
- `refs/` inspiration images (characters/, weapons/, hud/, style/). `textures/<area>/` kept map art.
- `poses/<anim>.txt` reusable keyframe pose lists (idle, walk, run, jump, dash, attack, throw, hurt, death, fly; Siya weapons: fuljadi, rocket, chakri).
- `out/` scratch (gitignored; `out/batch/` = batch queue + job records). `ab/` the tool: `prompts.py` holds ALL
  prompt text, `pixel.py` cleanup, `batch.py` Vertex batch jobs.
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
| flyer | 80 | 40 | winged demon (32x28 + wings), Robin smaller (`--height 40`) |
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
  automatically. Flyers/props/projectiles: `--anchor center`.
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

## 3. Map textures and parallax layers
```bash
python -m ab texture forest-concept "dusk forest level, ..." --mode concept -n 4  # pick an art direction first
python -m ab texture forest-earth "dark mossy earth, roots ..." --mode tile --tile 128   # platform fill
python -m ab texture forest-earth-cap "moss lip with grass tufts" --mode cap --cap-height 32  # top-edge strip
python -m ab texture forest-far "dusk forest silhouettes, ..." --mode layer --aspect 21:9    # opaque, 1080px tall
python -m ab texture forest-near "hanging vines and roots" --mode cutout                    # transparent shapes
cp out/textures/forest-earth/01.png textures/forest/forest-earth.png
python -m ab blend textures/forest/forest-earth.png textures/forest/forest-rock.png --keep  # A__B transition
python -m ab board forest                         # -> out/textures/board.png, mock side view of the area
```
- Modes: `tile` seamless square fill (128 art px = 64 units); `cap` transparent strip along a platform's
  top edge, full-width seamless, `--cap-height` art px tall (default 32), the walking surface a third of
  the way down; `concept` a 16:9 mock level screen for choosing art direction (not used in game);
  `layer` opaque parallax; `cutout` parallax shapes with transparency.
- **Terrain scale:** most platforms are thin 32-unit (64 art px) slabs, so a fill shows barely half a
  tile; **caps and fringes carry most of the look**. Spend iterations there; keep fills calm.
- Check `sheet.png` / `NN-tiled.png` for seams before keeping. `ab blend A B` builds a transition tile
  in code (no generation; `--seed N` for another boundary). `ab board [area]` composes the kept
  `textures/<area>/` fills (`*-cap.png` as caps, `A__B.png` as transitions) into a mock side view.
- Viewport is 960x540 game units = 1920x1080 art px. Existing forest layers: `textures/forest/j1-j4.png`.

**Terrain in Godot:** `scripts/levels/terrain_skin.gd` (`TerrainSkin` node) dresses the plain Body/Edge platform
polygons under `Terrain` with `fill`, `cap`, `end_cap`, `fringe` and `one_way_cap` textures at scale 0.5.
To review a kit in-engine without editing a level, put `fill/cap/end/fringe/oneway/bg.png` (any subset)
in one folder and screenshot (from the repo root; in a fresh worktree run `godot --headless --path . --import` once first):
```bash
xvfb-run -a godot --path . --resolution 1920x1080 -s tools/terrain_shot.gd -- <level.tscn> <kit dir> <out.png> <camera x>
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

## Speed, rate limits and batch
Pro image models on Vertex use Dynamic Shared Quota: 429 RESOURCE_EXHAUSTED means Google's shared pool
is busy, not a per-project cap, so extra keys/projects don't help. The tool backs off and retries (up to
~5 min). Three ways around it, all flags on `sprite`, `frames`, `texture` and `ui`:
- `--split pro,flash`: alternate candidates between Pro and Flash so both capacity pools work at once;
  sheets label Flash-made candidates `NN flash`. Good default when iterating live on a big run.
- `--fallback flash`: stay on Pro, switch a request to Flash only after its retries run out (also labelled).
- `--batch`: Vertex batch prediction, **half price and no 429s**, but results take minutes to hours.
  Use it for big queues (a whole animation list, many textures, overnight); use live for quick single
  iterations where you need to see the result now.

```bash
python -m ab frames siya run --batch               # queue (pending raws only); prints count + cost
python -m ab texture forest-earth "..." -n 6 --split pro,flash --batch   # one job per model on submit
python -m ab batch submit                          # cap check, upload, one Vertex job per model
python -m ab batch status                          # queue + job states/counts
python -m ab batch wait                            # poll, then fetch    (or: python -m ab batch fetch)
```
- Queue: `out/batch/queue.jsonl` (`ab batch clear` drops it); `submit --model flash` runs the whole queue
  on one model. Jobs run in location `global` from `gs://<project>-ab-batch` (made by `setup.sh`,
  objects deleted after 7 days); job records in `out/batch/jobs.json`.
- `fetch` writes each image to its raw path, then re-runs every queued command (cleaning only: sheets,
  previews, strips appear as usual). Failed requests are refunded in the ledger and land back on the
  queue for the next submit. Safe to run repeatedly. Batch runs never auto-regenerate problem
  candidates (`--retry`); queue a redo with `--only N --batch`.
- Spend: batch cost is charged to the ledger at submit (half the live price), so `doctor` stays truthful.

Never upgrade billing, buy provisioned throughput, or use AI Studio keys (trial credits cover Vertex
only). Spend is capped by `~/nanobanana/gen.py` (ledger `~/nanobanana/spend.json`); `python -m ab doctor`
shows spend, the batch bucket and unfetched batch jobs.

## Using art in the game
Copy chosen PNGs into the Godot project (e.g. `assets/sprites/<name>/`); asset-builder has a
`.gdignore`, so Godot never imports it. Use them at **scale 0.5** with the sprite's `anchor` as the
origin offset (feet on the collider bottom). The project already uses nearest filtering.
