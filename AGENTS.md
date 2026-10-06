# Repository Guidelines

## Project Structure & Module Organization

Siyaraj is a Godot 4.7.2 2D platformer using the Compatibility renderer. Open `project.godot`; the entry scene is `scenes/main/playtest_menu.tscn`. Forest, river and palace drafts and developer snapshots are available from this menu. The original prototype is `scenes/main/main.tscn`. See `docs/playtest_menu.md` for launch and editing details.

- `scripts/` groups GDScript by player, combat, enemies, bosses, UI, levels, effects, dev tools, and main integration.
- `scenes/` contains corresponding `.tscn` scenes. `scenes/dev/` holds the dev-only sandbox (one selectable enemy, for isolated encounter work) and the weapons playground; `scenes/bosses/` holds each boss and its isolated arena; `scenes/main/movement_playground.tscn` remains for movement tuning.
- `resources/player/default_movement.tres` stores shared movement tuning.
- `tests/` contains physics regression scripts; `tools/` contains smoke-build helpers.
- Bosses (Khara, Ravan) share the generic `scenes/ui/boss_health_bar.tscn`; boss-specific UI is a small add-on node, not a second bar. Boss design docs live in `docs/bosses/`.
- `docs/team_workflow.md` records ownership and gameplay contracts. `asset-builder/` contains local sprite tooling and reference images; current gameplay uses scene/script placeholders.

## Build, Test, and Development Commands

Use Godot 4.7.2. Run `godot --path . --editor`, then F5 for the playtest menu or F6 for the current scene.

On the Linux workstation, Godot 4.7.2 is installed persistently at
`/home/solan/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`.
The `/home/solan/.local/bin/godot` launcher is on the login-shell PATH. If
`godot` is unavailable in a non-login shell, use that launcher's absolute path
and set `GODOT_BIN=/home/solan/.local/bin/godot` for the smoke-build helpers.
Reuse this installation; do not download Godot into a temporary directory.

On the Windows workstation, use the existing executable at
`C:\Users\desai\AppData\Local\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`.

Run all regression checks from the repository root:

```sh
godot --headless --path . --script res://tests/movement_check.gd
godot --headless --path . --script res://tests/dash_check.gd
godot --headless --path . --script res://tests/combat_check.gd
godot --headless --path . --script res://tests/course_check.gd
godot --headless --path . --script res://tests/flying_enemy_check.gd
godot --headless --path . --script res://tests/ground_shooter_check.gd
godot --headless --path . --script res://tests/brute_check.gd
godot --headless --path . --script res://tests/forest_check.gd
godot --headless --path . --script res://tests/forest_rooms_check.gd
godot --headless --path . --script res://tests/forest_encounters_check.gd
godot --headless --path . --script res://tests/weapons_check.gd
godot --headless --path . --script res://tests/weapons_map_check.gd
godot --headless --path . --script res://tests/forest_weapons_check.gd
godot --headless --path . --script res://tests/khara_boss_check.gd
godot --headless --path . --script res://tests/ravan_check.gd
godot --headless --path . --script res://tests/next_levels_check.gd
godot --headless --path . --script res://tests/playtest_menu_check.gd
godot --headless --path . --script res://tests/campaign_flow_check.gd
godot --headless --path . --script res://tests/palace_layout_check.gd
```

`GODOT_BIN=godot ./tools/smoke_build.sh` imports resources and exports `builds/linux/siyaraj.pck`. `GODOT_BIN=godot ./tools/run_smoke_build.sh --headless --quit-after 120` launches that pack outside the editor. Substitute the executable path when needed. Standalone Linux exports require matching export templates.

## Coding Style & Naming Conventions

Follow existing GDScript: tab indentation, typed declarations, `snake_case` files/functions/variables, `PascalCase` class names, and uppercase constants/enum members. Separate functions with blank lines. `.editorconfig` requires UTF-8; no formatter or linter is configured. Preserve companion `.gd.uid` files.

Use named input actions. Player movement owns velocity; combat requests knockback through controller APIs. Enemies and boss hazards damage Siya only through `take_damage`, so ground/air dash i-frames (`is_invulnerable()`) apply everywhere. Coordinate ownership changes using `docs/team_workflow.md`; main-scene edits belong to integration.

## Testing Guidelines

Tests are custom `SceneTree` scripts, named `<feature>_check.gd`, exercising real physics and collisions. Failures exit nonzero. Extend relevant checks for changed behavior, run all listed suites before integration, and manually playtest movement/combat readability. No numeric coverage threshold is configured.

## Commit & Pull Request Guidelines

History uses concise, imperative messages such as `feat: add rocket dash and fall recovery`, with `feat/<topic>` branches. Use an appropriate prefix, such as `docs:` for documentation. Keep commits focused. PRs should describe behavior changes, link relevant issues, report checks and playtests, and include screenshots or clips for visual changes. Exclude generated `.godot/` and `builds/` output.
