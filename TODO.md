# Hackathon submission to-do

Art and animation are tracked separately and are not listed here.

As of 2026-10-06, `main` matches `origin/main` and all 17 regression suites pass.
The biggest gaps are the story mismatch with the proposal and the missing
start-to-finish route, so section 1 comes first.

## 1. Decisions to make first

Most of sections 2 to 4 depend on these.

- [x] **Check the jam rules:** deadline, platform (Windows, Web or Linux), upload
  format, and whether AI-generated art must be declared or is banned. Our sprites
  come from Nano Banana, so this one matters most.
  - [ ] Need to submit to itch.io, AI everything is allowed no declarations needed
- [x] **Match the story to what's built.** The proposal has Swaminathan, the Robin
  fight and the "Nathan Robin" twist. The code has Khara and Ravan as bosses and no
  Robin, Raj or Swaminathan. Either write a new story around Khara and Ravan, or add
  the Swaminathan/Robin fight. The proposal says the Robin fight and the lit-up
  ending stay in no matter what., 
  - [ ] Ravan should be Swaminathan, we need to make a simple name change, we need
- [x] **Fix the level order.** The proposal goes ghats → forest → palace. The code
  goes forest → river → palace (`next_level` in `scenes/main/forest.tscn` and
  `scenes/main/river.tscn`).
  - [ ] that doesn't matter
- [x] **Decide where each boss goes.** Khara and Ravan only exist in separate
  arenas. None of the three levels leads into a boss fight.
  - [ ] The last level should lead to a fight with Swaminathan and the second level to khara, we need to integrate that into the levels
- [ ] **Write down the cuts from the proposal:** anar slam (skyshot took its place),
  Robin strike, the shielded enemy and the sparkler combo chain. Then the submission
  page and the theme explanation can match the game.
  - [ ] This we'll do later

## 2. A playable game from start to finish

The game currently opens on the developer playtest menu, and the palace finish
leads nowhere.

- [ ] **Add a title screen** with New Game, Controls, Settings and Quit. Right now
  `run/main_scene` is the playtest menu.
- [ ] **Hide the developer tools in release builds:** snapshots, the encounter toggle
  and the checkpoint picker. One way is to check `OS.is_debug_build()` or a custom
  export feature tag.
- [ ] **Connect the levels:** level 1 → level 2 → level 3 → boss → ending.
- [ ] **Add boss arenas to the levels**, with an entrance, a checkpoint before the
  fight, and a door or gate that unlocks after the win.
- [ ] **Add an ending and credits:** the lit-up Diwali finale, Raj freed, then team
  credits.
- [ ] **Decide what happens on death or quitting mid-level.** At minimum, remember
  the furthest level reached during the session.

## 3. The jam themes (comic, twist, light)

Only light is partly in the game today. There is no comic presentation and no
twist yet.

- [ ] **Comic:** build a cutscene system that shows static panels with speech
  bubbles and advances on a key press. It's needed for the intro, before each boss
  and for the ending.
- [ ] **Comic:** add a dialogue/hint box for Robin's comments and tutorial prompts.
- [ ] **Twist:** whatever we choose in section 1 has to actually play out in the game.
- [ ] **Light:** the diya checkpoints exist. Still missing are the dark forest effect
  (the proposal cuts this first if time runs short) and the fully lit final
  celebration.

## 4. Robin (if kept)

Robin follows Siya and gives hints in the forest (see `docs/robin.md`). His sprites,
and hints for the river and palace, are still to do.

- [x] **Robin as a guide at minimum:** follows Siya and shows a hint near new
  hazards and moves. This is the proposal's fallback if time runs short.
- [ ] **The Robin boss fight**, plus a dizzy meter so Siya can knock him out without
  killing him, if we keep the proposal's twist.

## 5. Audio

There is no audio in the game yet: no `AudioStreamPlayer` anywhere and no audio
buses. Finding the music and sound files may belong on the asset list.

- [ ] **Set up the audio plumbing:** Music and SFX buses and a small autoload audio
  manager.
- [ ] **Play sounds at gameplay events:** lash, skyshot, chakri, dash, hits, enemy
  wind-ups, boss tells, lighting a diya, death and level complete.
- [ ] **Play music for each level and boss**, with crossfades between them.

## 6. Player-facing polish

- [ ] **Teach the controls** to someone who has never seen the game, inside the
  levels, instead of the current developer-style HUD.
- [ ] **Add a Settings screen** with volume sliders and fullscreen. Key rebinding is
  optional.
- [ ] **Add gamepad support** (optional but cheap). The input map has no gamepad
  bindings right now.
- [ ] **Balance the difficulty across a full run.** The river and palace encounters
  are still drafts. Check that a run lands in the 10 to 15 minute target.
- [ ] **Set the window title, app icon and boot splash.** The icon is still the
  default `icon.svg`.

## 7. Testing and bug fixing

- [ ] **Have people who have never played try it.** Note where they get stuck, which
  controls confuse them and how long a full run takes.
- [ ] **Add one automated test that plays the whole game:** title → each level →
  bosses → ending.
- [ ] **Do a bug bash, then freeze features.** The proposal reserves the last 10% of
  the time for "bug fixes and the build. No new features."
- [ ] **Run the release build on a machine that doesn't have Godot installed.**

## 8. Build and release

- [ ] **Add an export preset for the jam's platform.** Only a "Linux smoke test"
  preset exists, and a standalone build needs matching export templates. If the jam
  wants Web, test performance with the Compatibility renderer early.
- [ ] **Build a release (not debug) export** with the pack embedded. Leave the
  prototype course, playgrounds, terrain sampler, sandbox and `test_course.tscn`
  out of the build.
- [ ] **Clean up the repo:**
  - Commit or revert the editor's rewrite of the `skyshot` and `interact` inputs in
    `project.godot`.
  - Add a `docs/.gdignore` so Godot stops importing the screenshots and creating
    untracked `.import` files.
  - Decide whether `asset-builder/` should be committed or ignored.

## 9. The submission itself

- [ ] **Make the jam/itch page:** description, controls, screenshots, a GIF or
  trailer, and a short note on how the game uses comic, twist and light.
- [ ] **Credits and licences:** the team, any third-party audio or fonts, and the
  AI-art disclosure if the rules require one.
- [ ] **Rewrite the README for players.** Move the developer notes into `docs/`.
- [ ] **Upload early with a test build** to confirm the page and download work, then
  replace it with the final build.
