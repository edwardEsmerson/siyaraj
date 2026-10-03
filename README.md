# Siyaraj

A Godot 4.7.2 2D platformer prototype. Open `project.godot` and press F6 to run
the current scene or F5 to run the main scene.

Running and variable-height jumping are implemented, including acceleration,
deceleration, coyote time and jump buffering. The main scene is a grey-box
movement playground with steps, gaps, a low ceiling and a lower safety floor.
A horizontal camera follows Siya through the course. R restarts at the spawn.

Open `scenes/enemies/enemy_test.tscn` and press F6 for a separate enemy patrol,
damage, knockback and death test. Its hit button is a development tool.
The main course's enemy remains a placeholder. Dash, player attacks, player
health, enemy attacks and final art are later milestones.

Controls: A/D or arrows to move, Space to jump, Shift to dash, J to attack,
and R to restart. Hold Space for a full jump or release early for a short jump.
Shift and J are mapped for the next milestones but have no gameplay effect yet.

Movement tuning lives in `resources/player/default_movement.tres`. Run the
physics regression check with:

```sh
godot --headless --path . --script res://tests/movement_check.gd
```

See [the team workflow](docs/team_workflow.md) for ownership, agreed rules,
integration contracts, and the next tasks.

Use the Compatibility renderer for this simple 2D prototype. The viewport is
960 x 540 with nearest-neighbour texture filtering and preserved aspect ratio.

## Smoke build

Set `GODOT_BIN` to your Godot 4.7.2 executable if it is not on PATH, then run:

```sh
GODOT_BIN=/path/to/godot ./tools/smoke_build.sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh
```

The smoke build exports a PCK and runs it with the installed Godot executable,
outside the editor. It is not a standalone distributable executable.
Generated files go in the ignored `builds/linux/` directory. The export preset
packs the main scene, isolated enemy test and their dependencies, excluding the
proposal, regression checks and team docs. To run the enemy test from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/enemies/enemy_test.tscn
```

For a standalone Linux build, install the matching 4.7.2 export templates via
Godot's **Editor > Manage Export Templates**, then use **Project > Export**:

```sh
mkdir -p builds/linux
godot --headless --path . --export-debug 'Linux smoke test' builds/linux/siyaraj.x86_64
```

Linux is the initial smoke-test target. Confirm the submission platform before
adding its export preset.
