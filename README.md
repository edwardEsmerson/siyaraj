# Siyaraj

A Godot 4.7.2 2D platformer prototype. Open `project.godot` and press F6 to run
the current scene or F5 to run the main scene.

The first setup milestone is in place: separate player, enemy, course, and main
scenes; named inputs; collision layers; editable movement settings; and restart.
Movement, attacks, enemy AI, health, and a following camera are not implemented yet.
The setup screen reports input actions so the team can check keyboard mappings.

Controls: A/D or arrows to move, Space to jump, Shift to dash, J to attack,
and R to restart. During setup only input reporting and restart are functional.

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
packs the main scene and its dependencies, excluding the proposal and team docs.

For a standalone Linux build, install the matching 4.7.2 export templates via
Godot's **Editor > Manage Export Templates**, then use **Project > Export**:

```sh
mkdir -p builds/linux
godot --headless --path . --export-debug 'Linux smoke test' builds/linux/siyaraj.x86_64
```

Linux is the initial smoke-test target. Confirm the submission platform before
adding its export preset.
