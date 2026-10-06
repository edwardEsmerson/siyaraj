# Character library

The complete library lives on `feat/character-art` in `.claude/worktrees/character-art`,
based on main `8e6c0a8`: seven new base assets, 73 animation sets and 195 ordered frames.

Open this worktree's `project.godot`, open `scenes/dev/cast_preview.tscn`, and press
**F6**. Select a character/action, play or pause, step frames, flip, show collider/anchor
overlays, and switch checker, forest or title backgrounds. Default display is **scale
0.5**, nearest filtered: two art pixels per game unit. Khara's separate gada follows
his registered hand for every pose. Swaminathan's ten heads have their own action
selector; `faces` assigns distinct static expressions.

The approved Siya, Robin, basic rakshas and winged demon identities are retained.
Robin remains 48 art pixels; existing fly/perch frames are reused, with fly at 10 FPS.
The `point` alias uses `hint`; `talk` uses the existing perch frames at 5 FPS.
Aliases are compatibility names outside the 73-set total.

The library is ready for later gameplay integration. Controllers and level scenes
retain their existing behavior.

## Files and selections

- `asset-builder/cast_manifest.json`: briefs, references, dimensions, poses, timings,
  palette policy, preferred generation settings, actual source models and approval.
- `asset-builder/sprites/<subject>/`: approved bases and kept sources, ordered PNGs,
  strips, GIFs, poses and metadata; generated source sheets/prompts where used.
- `assets/sprites/<subject>/cast_frames.tres`: loadable Godot SpriteFrames.
- `assets/sprites/<subject>/cast_meta.json`: common canvas/anchor and attachment data.
  Each action also contains its PNGs, strip, GIF and metadata.
- `assets/sprites/cast_index.json`: complete preview catalog.
- [GIF gallery](cast_review.html): all 73 sets and links to strips.
- [Verification record](character_library_status.md).

New bases: Raj 04, ground shooter 03, brute 04, Khara 02, gada 01,
Swaminathan body 02 and head 03. The user chose Khara/body 02 and approved Siya's
four run frames, then waived further approval checkpoints. Remaining art was
reviewed and kept by the agent.

## Production and geometry

Tooling from `e06d9f0` and `5289228` was ported while retaining main's newer art/UI.
Batches resolve to 1K before prompts and references are prepared. Explicit 2K/4K
batches are rejected, following Google's
[batch inference limits](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/batch-inference).
References from older 2K sprites are prepared at the requested resolution.

The intended route was Pro 1K batches and live Pro 4K for large bodies. A successful
Siya run batch pilot preceded expansion. Persistent Vertex 429 capacity failures
required live Flash and then **imagegen transparent sheets**, including remaining
large-body actions. This is not an all-Pro or all-4K production. Actual models and
sheet dimensions are recorded per set, separately from the preferred settings.
Completed Vertex outputs were preserved; canceled unfinished batches were refunded.
The existing shared ₹25,000 Vertex cap is unchanged. Imagegen tool outputs do not
charge that local ledger.

Imported sheets use one source camera grid calibrated against a reference pose.
Crouching, fallen and expanded poses retain their physical scale. Uniform sampling
avoids the [Pixel Snapper elastic walker's](https://github.com/Hugo-Dz/spritefusion-pixel-snapper)
variable cell counts. Connected-component extraction preserves grid-crossing limbs;
reviewed effect ownership keeps detached projectiles with the right actor.
Earlier approved pilots retain their existing pixels.

Feet share a baseline; flying/head frames use their center. Expanded silhouettes
receive shared padding. Export pads every action and base to a common canvas without
resizing individual poses. The gada was normalized once to 120 art pixels before
registration; its native pivot is [96, 130]. Khara's 26 attachment entries record
hand offsets, rotation and visibility. His gada is hidden while hands perform other
actions and during defeat.

Documented timing, loops and final-frame holds are retained. Default playback is
8 FPS; Robin fly remains 10 FPS. Static expressions use `none` playback. GIF timing
uses cumulative 10 ms rounding to preserve cycle length.

## Builder commands

Run from `asset-builder/` using `/home/solan/ml/bin/python -m ab`.

```sh
python -m ab cast status
python -m ab cast validate --complete
python -m ab cast export --complete
python -m ab cast review
python -m ab cast review --wave movement

# Preparation is a dry run unless --execute is supplied.
python -m ab cast prepare --wave combat

# Regenerate selected IDs, review, then keep.
python -m ab frames siya hurt --only 2
python -m ab keep siya hurt

# Import at one shared source grid; then review and keep.
python -m ab cast import-sheet raj sheet.png --animations sulk freed --columns 2 --rows 2 --pixel-size 4 --calibration-cell 3

# Attachment coordinates refer to the native source before export padding.
python -m ab cast attach khara-gada --x 96 --y 130
python -m ab cast attach khara --anim slam_impact --frame 1 --x 55 --y -30 --rotation 90
```

Use `--start-cell 1 --calibration-cell 1` when a sheet starts with a neutral copy.
`--effect-owner 11:10` assigns detached effects from cell 11 to actor 10.
`attach --hide` records intentional hiding. `--view` and `--subject` preserve base
composition in animation prompts. Palette locking is default; listed effects use
`--free-palette`.

Queues/job files are local and atomic, with unique cloud prefixes. Partial submission
preserves successful model lanes. Fetch retains completed raws and retries downloads.
Missing rows remain pending; only explicit failed responses receive a once-only
refund. `--only` can resubmit previously fetched frames.

```sh
/home/solan/ml/bin/python -m unittest discover -s checks -v
cd ..
/home/solan/.local/bin/godot --headless --path . --editor --import
/home/solan/.local/bin/godot --headless --path . --script res://tests/cast_preview_check.gd
```

Run the nineteen repository regression suites in AGENTS.md before integration.
Automated checks validate resources and geometry; use the F6 preview to assess
motion and readability at gameplay scale.
