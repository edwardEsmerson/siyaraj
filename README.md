# Siyaraj

A Godot 4.7.2 2D platformer prototype. Open `project.godot` and press F6 to run
the current scene or F5 to run the main scene.

Running, fixed-height jumping, coyote time, jump buffering, and rocket dash are
implemented. Tapping or holding Space produces the same jump height. Dash can only start while airborne, stops
at walls, grants no invulnerability, and restores its air charge on landing.

Siya has a single sparkler melee swing with wind-up, an active hit window, and
recovery. She can run and jump while swinging; dash, hurt, and death cancel it.
Each swing damages an enemy at most once. Siya and the guard each have three
health. Damage applies knockback and protects Siya for 0.8 seconds. The combined course shows a brief death cue before restarting.
The isolated arena restarts immediately; R also restarts.

The guard patrols, approaches Siya, signals an attack with an orange wind-up,
strikes, and recovers. Getting hit cancels its attack. The combined course places two dash gaps before the encounter.
Defeat the guard to open the exit, jump the last gap and reach the turquoise flag.
The finish shows elapsed time and a replay prompt. Dash trails, sparkler arcs,
hit flashes and short spark bursts make actions easier to read.

The flying enemy patrols left and right at a fixed altitude, including while
charging a shot. Its orange charge locks aim at Siya's current position; move
away to dodge the straight projectile, then jump and press J to strike it.
Three hits defeat it. Hits interrupt charging without changing its altitude.
Shots stop at the player or solid world, respect Siya's damage protection, and
expire after three seconds. Shots already fired remain active after defeat.
The main course includes a flyer before the guard; only the guard opens the exit.

The ground shooter patrols with gravity and turns at walls and platform edges.
It stops for a purple charge, then fires a slower purple homing bolt that curves
toward Siya. Its limited turning speed lets you jump or air dash past it; bolts
stop at solid world and expire after 2.8 seconds. J interrupts the charge and
three hits defeat the shooter. The main course places it after the guard.

For isolated tuning, open `scenes/main/movement_playground.tscn` or
`scenes/combat/combat_arena.tscn` and press F6. The original
`scenes/enemies/enemy_test.tscn` remains a separate button-driven damage test.
Open `scenes/combat/flying_enemy_arena.tscn` with F6 to test just the flyer.
Open `scenes/combat/ground_shooter_arena.tscn` with F6 to test just the shooter.

Controls: A/D or arrows to move, Space to jump, Shift to dash, J to attack,
and R to restart. Holding J does not automatically repeat attacks.

Movement tuning lives in `resources/player/default_movement.tres`.
Player health/protection can be tuned on the player root; attack timing, reach,
and knockback on its Sparkler child. Enemy detection and speed live on the enemy
root; enemy attack timing lives on its MeleeAttack child.
The flying enemy root exposes patrol speed/radius, detection range, charge and
recovery timing, and projectile speed, damage, lifetime, and knockback.
The ground shooter also exposes gravity and projectile turning speed (radians
per second). Its projectile uses the same swept collisions and player damage API.

Run the physics regression checks with:

```sh
godot --headless --path . --script res://tests/movement_check.gd
godot --headless --path . --script res://tests/dash_check.gd
godot --headless --path . --script res://tests/combat_check.gd
godot --headless --path . --script res://tests/course_check.gd
godot --headless --path . --script res://tests/flying_enemy_check.gd
godot --headless --path . --script res://tests/ground_shooter_check.gd
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
packs the main scene, movement playground, all three combat arenas, isolated enemy test,
burst effect and their dependencies, excluding the
proposal, regression checks and team docs. To run the enemy test from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/enemies/enemy_test.tscn
```

To run the combat arena from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/combat/combat_arena.tscn
```

To run the flying enemy arena from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/combat/flying_enemy_arena.tscn
```

To run the ground shooter arena from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/combat/ground_shooter_arena.tscn
```

For a standalone Linux build, install the matching 4.7.2 export templates via
Godot's **Editor > Manage Export Templates**, then use **Project > Export**:

```sh
mkdir -p builds/linux
godot --headless --path . --export-debug 'Linux smoke test' builds/linux/siyaraj.x86_64
```

Linux is the initial smoke-test target. Confirm the submission platform before
adding its export preset.
