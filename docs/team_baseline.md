# Shared team baseline

`main` is the starting point for team work. The `team-baseline-2026-10-06` tag
marks this integration so the team can return to the same tested revision.
Keep new changes on a feature branch and open a PR back to `main`.

## What was consolidated

| Work | Included in the baseline |
| --- | --- |
| Forest, river and palace design worktrees | Already collected in `feat/level-design` and merged through #14. Their original commits are equivalent to the collected changes. |
| World kits, character library, title, menus, Robin and existing movement/weapon fixes | Already on `main`; the older remote branches contain no additional work. |
| #24, `fix/dash-reach` | Air-dash exit carry restores the authored route's reach while retaining vertical momentum. |
| #25, `feat/b1-b3-playability` | Swaminathan naming, Robin hints across all levels and gamepad controls. |
| #26, `feat/swaminathan-hp-heads` | One health pool, permanent head loss, living-head attacks and phase healing for the final boss. |
| #27, `t3/add-level-2-ghats-boss` | Dhoomketu and the river showdown. This had reached the health-regeneration branch but had not reached `main`. |
| #28, `feat/siya-animations` | Siya's gameplay animations across the shared player variants. |
| #29, `t3/level-two-plank-bridge` | Four-board bridge repair with grounded E pickup/placement, persistent built planks and the final jump/dash crossing. |
| `feat/easier-khara` | One-damage slams, one shockwave and ladi sequence at a time, and corrected burst interpolation. |
| `feat/semantic-audio-names` | Audio files and their catalog, now tracked so teammates receive them. Playback is still a task in `TODO.md`. |

The combined campaign is title, forest, Khara, river, Dhoomketu, palace,
Swaminathan and ending. Developer snapshots include all three boss arenas and
showdowns. Terrain-only runs bypass bosses.

Integration fixes cover standalone level initialization, Siya's victory animation
in every boss arena, the final boss's updated HUD instructions, and checkpoint
tests waiting for the curtain tween's completion before checking the teleport.
The river bridge opening was adjusted for the restored air-dash reach so all
four planks are needed before the final crossing. HUD backdrops keep the status text readable over the world art. The smoke preset
includes runtime-loaded assets, and `tools/pack_check.gd` verifies the exported
scenes and art from outside the repository.
The new boss fight takes precedence over the older regrowth/weak-point design.

## Start a task

From an existing checkout with your work committed or stashed:

```sh
git fetch origin --prune
git switch main
git pull --ff-only origin main
git switch -c feat/your-task
```

To work in a separate directory instead:

```sh
git fetch origin --prune
git worktree add -b feat/your-task ../your-task origin/main
```

Open that directory's `project.godot` in Godot 4.7.2. F5 opens the title screen;
the debug Playtest menu gives access to levels and developer snapshots. The old
design worktrees remain available for reference. Start new work from updated
`main` rather than continuing their old branches.

## Verify before sharing

Set `GODOT_BIN` to your Godot 4.7.2 executable and import the project once:

```sh
godot --headless --path . --editor --import
python tools/run_checks.py
```

On Windows PowerShell, for example:

```powershell
$env:GODOT_BIN = 'C:\Users\desai\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT_BIN --headless --path . --editor --import
python tools/run_checks.py
```

The runner discovers every `tests/*_check.gd`, runs each at 60 fixed FPS, and
fails on a nonzero exit, a script error, missing success output or a timeout.
Logs stay in ignored `.godot/checks/`. The baseline has 29 suites covering
movement, weapons, enemies, checkpoints, all levels, bosses, campaign navigation,
menus, companion hints, character assets, world skins and player animation.

The baseline also passed the exported-pack check across all 17 distinct menu
scenes and rendered checks of menus, levels and all three boss arenas.

Also export and launch the smoke PCK outside the project using the existing
`tools/smoke_build.sh` and `tools/run_smoke_build.sh` helpers. Run the packed-resource check from outside the project with `--main-pack` pointing
to the PCK and `--script` pointing to the absolute path of `tools/pack_check.gd`.
Playtest changed sections yourself; automated route checks do not judge how the game feels.

## Remaining work

`TODO.md` remains the shared task list. Swaminathan's replacement body-state art,
enemy and Khara animation integration, audio playback, story work and release
exports are still open. Those tasks are separate from branch consolidation.
Keep the existing boss placeholder fallback until the replacement art is ready.
