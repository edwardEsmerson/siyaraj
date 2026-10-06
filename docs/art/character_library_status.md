# Character library verification

Worktree: `.claude/worktrees/character-art` · branch: `feat/character-art` ·
base: main `8e6c0a8`.

**Complete:** seven new approved base assets, 73 approved animation sets,
195 ordered frames (71 new sets / 189 new frames; Robin fly/perch reused).
All eleven subjects have approved bases. All requested movement, combat, story
and future boss states are included. The sprite/animation checklists are updated.

## Delivered

- Approved sources under `asset-builder/sprites/`, including poses, metadata,
  original generated sheets and prompts.
- PNG frames, strips, timed GIFs, common canvas/anchor metadata and
  `cast_frames.tres` resources under `assets/sprites/<subject>/`.
- Robin `point`/`talk` aliases, ten selectable static head expressions, burnt
  moustache and head-destruction frames.
- Khara's separate 120-pixel gada, handle pivot and all 26 hand registrations;
  explicit hiding for actions using both hands and for defeat.
- F6 preview with play/pause, stepping, flip, zoom, overlays, three backgrounds,
  Khara/gada composition and independent Swaminathan head actions.
- [All-set GIF gallery](cast_review.html).
- Builder view/subject options, early 1K batch enforcement, mixed-resolution
  references, uniform animation grids, common canvas padding, resumable
  submission/fetch and strict complete export validation.

The user selected Khara/body 02 and approved Siya's run pilot. The user then
waived further approval checkpoints and authorized agent selection/review/keep.

## Verification completed

- **22 Python builder checks passed**, including resolution handling, registration,
  source sampling, grid-crossing limbs, detached projectile ownership, GIF timing,
  incomplete keep protection, interrupted model-lane submission, retryable fetch,
  re-submission and a complete 195-frame export fixture.
- `ab cast validate --complete` and `ab cast export --complete` passed with actual
  approved assets.
- All 195 actual exported frames have binary alpha; every GIF's cumulative timing
  matches its manifest within format rounding.
- **Godot 4.7.2 import passed.**
- **cast_preview_check passed** with real resources: all 73 sets / 195 textures
  load, Robin aliases/timing, stepping/flip/background controls, ten expression
  heads and intentional gada hiding. Additional in-memory fixtures exercise
  missing attachment handling and rotation.
- **All 19 repository regression suites passed after final export**: movement,
  dash, combat, course, flying enemy, ground shooter, brute, forest, forest rooms,
  forest encounters, weapons, weapons map, forest weapons, Khara boss, Swaminathan,
  next levels, playtest menu, menus and Robin.
- **git diff --check passed.**
- Actual Compatibility-renderer captures reviewed at scale 0.5:
  [Khara idle](cast_preview.png), [windup](khara_windup.png),
  [impact](khara_impact.png), [ten-head fury](swaminathan_preview.png),
  [Siya run against forest](siya_preview.png).
- All action sheets reviewed. Expanded poses share padding and are not resized.
  The remaining Robin hover size warning describes extended wings; it was
  visually reviewed as an expanded silhouette.

## Generation route and remaining scope

A successful 1K Pro Siya run batch pilot preceded expansion. Persistent Vertex
429 capacity failures required live Flash and then imagegen transparent sheets.
The final 195 frames comprise 172 imagegen frames, 14 Pro frames, 3 Flash frames,
and 6 reused approved Robin frames. Large-body actions therefore include sheet
generation rather than the originally preferred live Pro 4K route. Actual model
and sheet/grid metadata identify each set's production path.

Completed requests were preserved, unfinished canceled batch reservations were
refunded, scratch/job files remained worktree-local, and the existing shared
₹25,000 Vertex cap was preserved. Imagegen tool usage is outside that local ledger.

Gameplay wiring, background integration, general props/UI/effects and the Swaminathan
code rename remain separate work. The user can assess animation feel and timing
in the F6 scene before gameplay integration.
