# Siyaraj

Start new work from `main`. See [the shared team baseline](docs/team_baseline.md)
for the integration audit, worktree commands and verification steps.

F5 opens the title screen; choose Playtest menu in debug builds.
Select the forest, river/ghats, or temple/palace;
start at the beginning or a checkpoint section, and toggle enemy encounters.
The developer snapshots selector opens the weapons playground, movement, the dev
sandbox (preset to each enemy), the Khara, Dhoomketu and Swaminathan boss arenas, terrain and
canopy tests, the full cast preview and Raj's ending. Esc pauses gameplay scenes
and offers restart or level select.
See [playtest menu and draft editing](docs/playtest_menu.md).
The enemies and Khara now use their approved cast animations in gameplay;
see [cast integration and remaining assets](docs/cast_gameplay.md).

Gamepad controls are available throughout gameplay and menus. Open Controls from
the title or pause menu for keyboard and controller bindings; see the
[controller mapping](docs/ui.md#controller-controls).

The river and palace are editable grey levels, each 14,400 pixels long with five
manual diya checkpoints. The forest exits into Khara's showdown; the river ends
at Dhoomketu's ghats fight, then the palace ends at Swaminathan's showdown.
Enter advances at each exit or victory.
Boss fights start with fresh resources and retry inside the arena on death.
Terrain-only playtests bypass bosses. The menu also offers all three campaign showdowns
directly, alongside the original isolated boss arenas.

The forest level is `scenes/main/forest.tscn`. The current grey draft
is 21,600 pixels long, with high root climbs, narrow landings, ceiling sections,
a switchback climb, lower recovery routes and staged melee/ranged encounters.
Stand beside a diya and press E to light it and secure a checkpoint. Passing
one does not save. Death returns to the furthest lit diya with full health;
R clears all checkpoints and restarts the forest. Eight main encounters lead
through the clearing, hollow, canopy and shrine. The root chamber and canopy
nest have their own enemy challenges, local checkpoints and guarded far exits.
See [forest design and enemy handoff](docs/forest_level.md).

The root ridge and banyan climb also have E doors into isolated root and
canopy challenges. Their local diyas save within the room; the far door
returns to the forest entrance. The entrance door allows leaving early.
The nest has a tall trunk climb with vertical camera follow. See the
[Guacamelee footage and map notes](docs/guacamelee_research.md).

The forest now uses the three-weapon controller from PR #7. J performs a
single ground or aerial lash. L fires a skyshot with recoil, using one of
five shots. Hold K for a full charge, then release for a chakri spin.
Chakri has a 30-second cooldown. Ammo and cooldowns appear on the HUD.
Doors preserve health, remaining shots and cooldowns. Diyas only save your
position. Death and R restore the five-shot loadout and reset cooldowns.
For isolated practice, open `scenes/dev/weapons_playground.tscn` with F6.

Boss 1, Khara, has an isolated arena: open `scenes/bosses/khara_arena.tscn` with F6.
He telegraphs an orange gada slam with a ground shockwave, and lays ladi firecracker
strings that pop along the ground toward Siya. Yellow chevrons show the direction.
At half health he enrages, but attacks remain separate: one shockwave or ladi
sequence at a time, with no pincer. Slams deal one damage. See
[the Khara design doc](docs/bosses/boss1-khara.md). The forest exit opens his showdown.

Boss 2, Dhoomketu, guards the ghats in `scenes/bosses/dhoomketu_arena.tscn`.
His locked rocket paths, rolling chakris and marked anaar lanes lead into a
counterattack window. The river exit opens his showdown; victory unlocks the
palace. See [the Dhoomketu design doc](docs/bosses/boss2-dhoomketu.md).

Final boss, Swaminathan, has an isolated arena at `scenes/bosses/ravan/ravan_arena.tscn`
(F6) and ends the campaign. Strike him anywhere: every tenth of his health severs
his rightmost head for good, and only the heads still standing attack, each one
glowing before it strikes. Phase changes trigger Dashanan Fury: stand in the teal
lanes. See
[the Swaminathan design doc](docs/bosses/boss2-ravan.md).

All three bosses use the reusable boss health bar, `scenes/ui/boss_health_bar.tscn`.
Swaminathan adds a small head-indicator row above it. All boss hazards respect the
dash i-frames described below.

The earlier prototype course remains available at `scenes/main/main.tscn` with F6.
Its guard and finish-gate behaviour described below are unchanged.

A Godot 4.7.2 2D platformer prototype. Open `project.godot` and press F6 to run
the current scene or F5 to run the main scene.

Running, fixed-height jumping, coyote time, jump buffering, and rocket dash are
implemented. Tapping or holding Space produces the same jump height. Dash works on the ground
and in the air and stops at walls. One air dash is allowed, restored on landing;
a ground dash keeps that charge but starts a 0.25-second cooldown after it ends.
Dashing grants brief invulnerability (the dash plus 0.05 seconds): enemy swings,
shots and boss hazards pass through Siya, and a dodged shot ignores her afterwards. Dash
cancels any sparkler phase, including recovery. J pressed during a dash is held
and swings as the dash ends.

Siya has a single sparkler melee swing with wind-up, an active hit window, and
recovery. She can run and jump while swinging; dash, hurt, and death cancel it.
Each swing damages an enemy at most once. Siya and the guard each have three
health. Damage applies knockback and protects Siya for 0.8 seconds. The combined course shows a brief death cue before restarting.
The dev sandbox restarts immediately; R also restarts.

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

The Brute is a larger, muscular melee enemy after the guard. It has six health,
deals two damage with a wider strike, and resists knockback. It moves more slowly
and signals its attack with a 0.7-second orange wind-up, followed by a long
recovery. Step back, then counterattack; hits still interrupt its swing.
It uses ordinary enemy health and defeat feedback and has no boss phases.
The ground shooter patrols with gravity and turns at walls and platform edges.
It stops for a purple charge, then fires a slower purple homing bolt that curves
toward Siya. Its limited turning speed lets you jump past it or dash through it; bolts
stop at solid world and expire after 2.8 seconds. J interrupts the charge and
three hits defeat the shooter. The main course places it after the guard.

For isolated movement tuning, open `scenes/main/movement_playground.tscn` and
press F6. To fight one enemy alone, open the dev sandbox
`scenes/dev/sandbox.tscn`, pick `encounter` (Guard, Brute, Flyer, Shooter or
none) on its root, optionally enable `three_weapons`, and press F6.

Controls: A/D or arrows to move, Space to jump, Shift to dash (on the ground or
in the air, with brief i-frames), J to attack, and R to restart. The forest, boss
arenas and weapons playground add L for skyshot and hold/release K for chakri.
Holding J does not automatically repeat attacks.

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
python tools/run_checks.py
```

Set `GODOT_BIN` to your Godot 4.7.2 executable first. The runner discovers all
30 suites and rejects script errors even when Godot exits with code zero.
See [the shared baseline](docs/team_baseline.md) for platform commands.

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
packs the playtest menu, forest, river, palace, terrain sampler, prototype course,
movement playground, dev sandbox, weapons playground, Khara, Dhoomketu and Swaminathan boss arenas,
all runtime assets, including dynamically loaded world kits, while excluding
asset-building tools, regression checks and team docs. To run the sandbox (default Guard
encounter) from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/dev/sandbox.tscn
```

To run a boss arena from the pack:

```sh
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/bosses/khara_arena.tscn
GODOT_BIN=/path/to/godot ./tools/run_smoke_build.sh res://scenes/bosses/ravan/ravan_arena.tscn
```

For a standalone Linux build, install the matching 4.7.2 export templates via
Godot's **Editor > Manage Export Templates**, then use **Project > Export**:

```sh
mkdir -p builds/linux
godot --headless --path . --export-debug 'Linux smoke test' builds/linux/siyaraj.x86_64
```

Linux is the initial smoke-test target. Confirm the submission platform before
adding its export preset.
