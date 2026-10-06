# Hackathon submission to-do

Updated 2026-10-06. Everything left before the itch.io submission is listed here,
art and animation included, sorted by who should pick it up:

- **A. You (a human):** decisions, reviews, playtests and the submission itself.
- **B. A good LLM:** well-scoped work that follows patterns already in the repo.
- **C. A really good LLM:** cross-cutting work that needs design judgement, touches
  many systems, or could easily break the 25 regression suites.

Per-asset briefs, sizes and generation commands live in
`asset-builder/Sprites_List.md` and `asset-builder/Animations-List.md`. This file
says *what* is left and *who* does it, and points there for the *how*.

## Where things stand

- **Playable route:** title → forest → Khara → river → palace → Swaminathan → ending.
  Each boss is a separate showdown scene. A "TRAIL CLEARED / Enter: face Khara"
  screen leads into it, not an arena inside the level.
- **Done:** title screen, themed pause menu, controls panel, settings (master volume
  and fullscreen), debug-only playtest tools, Robin as a guide in all three levels, blocked-diya
  curtain transition (placeholder art), and `docs/.gdignore`.
- **Art exists but isn't in the game.** 73 approved animation sets (195 frames)
  sit in `assets/sprites/` for Siya, Robin, Raj, all four enemies, Khara with her
  gada, and Swaminathan. Only **Robin** is wired into gameplay. Siya, the enemies
  and both bosses still draw code placeholders.
- **World kits:** levels and both boss arenas are dressed through `WorldSkin` in all
  six styles (press V in a level to cycle). Merged in #15 and #19.
- **Red suites on `main`:** `course`, `dash`, `forest`, `forest_rooms` and
  `next_levels` fail since #17 (preserve vertical momentum during dash, `e5fff81`):
  some dash gaps and route links are no longer reachable. Fix this first (B0).
  The other 21 suites pass, `world_skin_check` included.
- **No audio plays.** There are no `AudioStreamPlayer` nodes and no buses.
  `assets/Audio/` is gitignored, so teammates don't have the music files.
- **Only export preset:** "Linux smoke test".

---

## A. You (human)

### Decisions (they block work in B and C)

- [ ] **Swaminathan's head rules.** The new sprite plan (see C1) has heads destroyed
  right to left. Decide:
  - Does *any* head hit count toward the rightmost head, or can Siya only damage
    the rightmost living head?
  - Do heads still **regrow**? Regrowth would make the sprite step back up a state.
    Suggestion: no regrowth; a destroyed head stays gone.
  - Should the **Dashanan Fury** super still bring back all ten heads? Suggestion:
    Fury uses only the heads still alive, which also makes it easier as he weakens.
- [ ] **Music licensing.** The tracks in `assets/Audio/` are from Diamond Rush and
  Prince of Persia: The Forgotten Sands, which are copyrighted. Decide whether to
  ship them, which risks a takedown on itch.io, or swap them for royalty-free/CC0
  music. Either way, un-ignore whatever we ship so the build and teammates get it.
- [ ] **The twist.** The final boss is now named Swaminathan. Is that the twist? Or does the
  Robin fight / "Nathan Robin" reveal from the proposal stay in? The answer decides
  whether C6 happens.
- [ ] **Story beats for the comic panels:** intro, before Khara, before Swaminathan,
  ending. Write them yourself, or have an LLM draft them for your approval.
  `asset-builder/Sprites_List.md` §8 has a starting script.
- [ ] **The cuts list:** anar slam, Robin strike, shielded enemy, sparkler combo.
  You marked this "later". It's needed for the itch page.
- [ ] **Vertex spend for the remaining art.** Approve each generation batch. The
  free-trial cap stays and billing is never upgraded.
- [ ] **The deadline.** Write the date here so the freeze in A4 has a date.

### Reviews

Open the file, judge it, then reply "fine" or "redo X".

- [ ] **The full cast:** open
  `C:\Users\solan\Desktop\git repos\siyaraj\docs\art\cast_review.html` in a browser
  and flag every animation that looks bad, as you did with Swaminathan. Better still, play
  the F6 scene `scenes/dev/cast_preview.tscn` to judge timing.
- [ ] **The current Swaminathan sprite is horrible.** It's already flagged and
  being replaced (C1). Don't wire the current `swaminathan` / `swaminathan-head`
  art into the fight.
- [ ] **Every art-integration PR** from B and C must include in-engine screenshots in
  `docs\screenshots\`. Check each one before merge.
- [ ] **Audio mix:** once B4 lands, listen to one full run for loud or quiet cues and
  bad loops.

### Playtesting and submission

- [ ] **First-time players:** have people who have never seen the game play it. Note
  where they get stuck, which controls confuse them and how long a full run takes.
  The target is 10 to 15 minutes.
- [ ] **Run the release build on a machine without Godot.**
- [ ] **Call the bug bash, then the feature freeze.** The proposal keeps the last 10%
  of the time for "bug fixes and the build. No new features."
- [ ] **Create the itch.io page** (the jam allows AI everything, no declaration
  needed). Upload a test build early, then the final one.
- [ ] **Write the credits:** team names and roles, plus any third-party music or
  fonts.

---

## B. Good LLM

### Code

- [ ] **B0. Make the suites green again (do this first).** Since #17, dashing keeps
  vertical momentum, which shortened jump + dash reach. `dash_check` (220 and 250 px
  gaps), `course_check` (times out), `forest_check`, `forest_rooms_check` and
  `next_levels_check` (route links such as `Branch5 -> BranchExit`,
  `CrownRest -> OuterBranch1`, `UpperLanding -> DashLanding`) fail. Tune the dash so
  the old reach comes back while keeping the momentum feel. Don't move level geometry
  or weaken the checks. Run only those five suites, since each one is slow.
- [x] **B1. Rename the final boss to Swaminathan** in all player-facing text:
  boss bar, intro/defeat banners, palace completion screen, playtest menu and
  docs. Existing `ravan` filenames and node paths remain stable for C1.
- [x] **B2. Robin hints for the river and palace.** Six hints in each level cover
  crossings, recovery routes, cover and encounters. Final-diya hints introduce
  Khara in the forest and Swaminathan in the palace. See `docs/robin.md`.
- [x] **B3. Gamepad bindings.** Every custom action has joypad bindings; menus
  confirm with A/Cross and pause/back with Start. The shared Controls panel shows
  keyboard and controller columns. See `docs/ui.md`.
- [ ] **B4. Audio plumbing:** Music and SFX buses, an `Audio` autoload with
  crossfading music, and per-bus volume sliders in `settings_panel`, keeping the
  existing master volume. Then play music per level, boss, title and ending.
  Starting cue choices are in `AUDIO_CATALOG.md`; wait for A's licensing decision
  before using them.
- [ ] **B5. SFX at gameplay events:** lash, skyshot, chakri charge and release, dash,
  Siya hit, enemy wind-up, enemy death, boss tells, diya lit, curtain, death and
  level complete. We have no SFX files yet: source CC0 ones (for example Kenney or
  freesound CC0), list them in `AUDIO_CATALOG.md`, then wire them.
- [ ] **B6. Death and quit behaviour:** remember the furthest level reached during
  the session and offer "Continue" on the title screen.
- [ ] **B7. Export presets:** add Windows and Web presets for itch.io, release (not
  debug), with the pack embedded. Leave out `prototype_course`, `test_course`,
  `terrain_sampler`, `movement_playground`, `main.tscn`, `scenes/dev/` and the
  playtest menu. Test Web performance on the Compatibility renderer early.
- [ ] **B8. Window title, app icon and boot splash.** Wire them up once the art in
  B11 exists. The icon is still the default `icon.svg`.
- [ ] **B9. Extend `tests/campaign_flow_check.gd`** to start at the title screen and
  run all the way to the credits. It currently starts at the levels.
- [ ] **B10. Rewrite the README for players.** Move the developer notes into
  `docs/`.

### Art and animation (generate with the `siyaraj-assets` skill, wire, screenshot)

- [ ] **B11. P0 props, effects and HUD** from `Sprites_List.md` §4–6. Props: diya,
  room door, toran gate, ladi cracker. Effects: lash arc, skyshot rocket, pop
  burst, dash flame, chakri spin, enemy bolt and shot, death puff, diya flame,
  shockwave, Khara's fire breath, lightning column, roar crest, fury pillar. HUD:
  health diya, ammo, chakri icon, boss bar frame, title logo, app icon. Each one
  replaces a drawn placeholder 1:1.
- [ ] **B12. Curtain art** for the blocked-diya transition. Left and right panels
  slide shut, fully cover the screen for the 0.5-second hold, then slide open. Keep
  the top-led pull, the curved trailing hem and the delayed settling
  (`scripts/levels/checkpoint_guard.gd`).
- [ ] **B13. Wire the four enemies' sprites** (`basic-rakshas`, `brute`,
  `ground-shooter`, `winged-forest-demon`). Map walk, idle, attack/charge/fire,
  recovery and death to each enemy's existing states. Keep the colliders, and time
  the attack frames to the existing hitbox windows.
- [ ] **B14. Palace guard palette:** recolour `basic-rakshas` and `ground-shooter`
  for the palace (no new art).
- [ ] **B15. Raj on the ending screen:** use the `sulk`, `dramatic` and `freed`
  animations.
- [ ] **B16. Tidy the art checklists.** Tick off the textures in `Sprites_List.md`
  §7 that the world kits already cover, so the remaining list is accurate.
- [ ] **B17. P1 extras:** Raj's cage, ladi cord, chakri charge glow, slam impact,
  Khara's flame crown, dialogue panel, title background, Swaminathan's hall (plus
  the lit version) and the Khara arena background.

---

## C. Really good LLM

- [ ] **C1. Rebuild Swaminathan as one body sprite per head state.** The current
  sprite is horrible. The ten heads are separate entities (`ravan_head.tscn` ×10)
  with their own art, and that must go.
  - **Art:** generate one full-body sprite for each head state, 10 heads down to 1
    (plus 0 / defeated). Heads are removed **right to left**, so state *n* shows the
    leftmost *n* heads. The same body, crown, moustache and pose must hold
    across all 10 sprites: generate state 10 first, get it approved, then derive
    the others from it. Re-do `idle`, `roar`, `exposed`, `fury`, `dying` and
    `dead` per state only if needed, or keep them to a minimal set (idle and hurt
    flash per state, plus fury and death).
  - **Code:** heads become invisible hurtboxes and attack origins positioned over
    the sprite. Losing a head swaps the body sprite and removes the rightmost living
    head's hurtbox. Rework the lunge telegraph, which can no longer move a head, so
    use a glow or flash on the attacking head instead. Rework regrowth, Fury lanes,
    the outside-in death burst and the head pips to the rules decided in A.
  - **Keep** `tests/ravan_check.gd` passing (update it to the new rules), and update
    `docs/bosses/boss2-ravan.md`. Send screenshots of all 10 states for review.
- [ ] **C2. Wire Siya's 15 animations into the player.** Drive a sprite state machine
  from the movement and combat state: idle, run, jump (frame picked by vertical
  velocity), dash (ground and air), lash, air lash (hit on frame 2), skyshot,
  chakri charge and release, hurt (with the existing blink), death, light diya and
  victory. Keep the 24×40 collider and scale 0.5, and flip with facing. All movement,
  dash, combat and weapons suites must still pass. Hand over a short clip or
  screenshots for review.
- [ ] **C3. Wire Khara's sprite and her separate gada.** The gada pivots on its
  handle, uses the 26 hand registrations and hides during two-handed actions and
  defeat. It has to line up with the existing slam and shockwave hitboxes and the
  phase-2 flame crown. `tests/khara_boss_check.gd` must pass.
- [ ] **C4. Comic cutscene system.** Show static panels with speech bubbles that
  advance on a key press, plus a dialogue/hint box with portraits for Robin and the
  tutorial prompts. Add a small tool change for panel generation
  (`Sprites_List.md` §8), then generate and wire the intro, pre-Khara,
  pre-Swaminathan and ending panels from the beats you approve in A. Needs:
  dialogue panel, portraits for Siya, Robin and Raj, and the P2 comic hit words
  (BOOM!, ZAP!, POP!, DHAM!).
- [ ] **C5. Boss arenas inside the levels.** Replace the "TRAIL CLEARED → Enter"
  jump to a separate showdown scene with a walk-in arena: entrance, a checkpoint
  before the fight, and a gate that unlocks after the win. Khara at the end of the
  forest, Swaminathan at the end of the palace. Keep "death retries the boss, not
  the level" (`campaign_flow_check`).
- [ ] **C6. The twist and Robin's fight** (only if A keeps it): the Robin boss, a
  dizzy meter so Siya knocks him out instead of killing him, and Robin's
  `hypnotised`, `dive`, `drop_sparks`, `dizzy` and `wake` animations, which already
  exist.
- [ ] **C7. Light theme payoff.** Add the dark forest effect, which is cut first if
  time runs short. Add the fully lit Diwali finale: the palace hall lights up, Raj
  is freed and credits roll. Use the lit-hall background from B17 and the
  fireworks effect.
- [ ] **C8. Teach the controls inside the levels.** First-time prompts at the right
  moments, through Robin and the C4 dialogue box, replacing the developer-style HUD
  text.
- [ ] **C9. Balance the full run.** The river and palace encounters are still
  drafts. Use the playtest notes from A to tune enemy counts, boss health and
  checkpoints toward the 10–15 minute target.
- [ ] **C10. Bug bash triage.** Before the freeze, go through playtest reports, fix
  the bugs and say no to new features.
