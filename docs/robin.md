# Robin

Robin is Siya's bird companion: `scenes/companions/robin.tscn` with
`scripts/companions/robin.gd`. He is in the forest, river and palace level scenes.
He has no collision and he never deals or takes damage. The Robin strike was cut,
so he is a guide only.

## What he does

- **Follows** Siya, hovering behind her head and mirroring her facing. He flies on a
  spring, so dashes pull him along quickly. After a long jump (a room change or a
  respawn) he snaps straight to her.
- **Perches** on Siya's head after she stands still for 2 seconds. He takes off
  as soon as she moves; idle pauses no longer trigger chatter.
- **Points out hints.** Each `RobinHint` area sends him to a spot to explain a
  new lesson or essential progression step. Hints show once per session, including
  death reloads. Shared `topic` keys also suppress repeated lessons across levels.
- **Stays quiet in combat.** Automatic enemy warnings and damage comments are
  disabled. Tutorials wait while Siya dashes, is hurt, uses a weapon, or has living
  enemy bodies or hostile hitboxes within 320 px. Starting combat clears a tutorial
  bubble. Defeat reactions remain.
- **Spaces tutorials.** A bubble must finish before another hint, followed by
  two seconds of quiet. A deferred hint retries while Siya stays in its area;
  leaving cancels that pending request without marking the lesson seen.
- **Obeys story scripts.** `say()` and scripted control keep their existing behavior.

## Adding hints

Instance `scenes/companions/robin_hint.tscn` in a level and set its `text`. The
trigger is a tall 64x480 column above the node, and its shape is local to each
instance, so it can be resized in the editor. `point` is where Robin hovers, relative
to the hint. The forest's hints are under `RobinHints` in `scenes/levels/forest.tscn`.
The river and palace each have six hints under their own `RobinHints`. Repeated
jump/dash, guard, brute and cover advice shares a `topic` with its first introduction.
A direct level playtest can still teach these lessons, while a campaign run skips
lessons already learned. Leave `topic` empty for unique progression guidance such
as the bridge's four planks and each boss approach. `once = false` remains available
for deliberately repeatable hints, with the same spacing and combat gates.

The forest introduces movement, air dash, guards, checkpoints, weapons, shooters
and brutes. The river adds cover and bridge construction. All three boss approaches
remain distinct. Story dialogue, Robin's final reveal and portraits are unchanged.
Session memory uses the existing `seen_hints` dictionary and `forget_hints()` API;
cross-session persistence belongs to the save/load system.

The homing missile lesson plays at X=2280, after ClearingGuard and before
ClearingRearShooter, the main route's first shooter. Like the guard and diya
hints, it waits until the nearby clearing fight is over. An earlier optional
Root Chamber visit teaches it at the room entry (450, -2050), before any of the
chamber's enemies come into range. Both triggers share `homing_dash`,
so players hear this advice once whichever route they take first. They use the
same combat deferral and quiet-time policy as other tutorials. `{dash}` in hint
text resolves to the named Dash action and its current keyboard/controller
bindings through the controls panel's InputMap helpers when Robin speaks.
The campaign shooter's missiles respect dash invulnerability, pass through Siya
and stop steering after a dodge. `tests/homing_dash_hint_check.gd` verifies both
first encounters, remapped prompts, deferral, reload/route repeat suppression,
and damage with and without a real dash.

`tests/robin_check.gd` enters authored triggers through the campaign, checks fresh
lessons and skipped repeat topics, reloads levels, and exercises combat deferral,
re-entry, automatic retry, bubble cancellation, weapon use and cooldown spacing.

## Art

Robin is a Jatayu-inspired firebird: vermillion wings tipped with cream and green,
a white vulture ruff, a hooked golden beak, a curled crest and a marigold tail fan.
The approved sprite and its keyframes are in `asset-builder/sprites/robin/`, generated
at 48 art px (24 game units, smaller than the 80 px flyer default so he can perch on
Siya). The game copies are in `assets/sprites/robin/`, and `robin_frames.tres`
defines three animations:

- `fly`: 4 wing-beat frames at 10 fps.
- `perch`: wings folded, standing still.
- `talk`: perched with the beak opening and closing. It plays only while he is
  perched and speaking.

`Visuals/Sprite` uses these at scale 0.5 with the frames centred. The art faces right,
and `Visuals` is mirrored for left. Remove the `SpriteFrames` and the placeholder
polygons come back. To redo a pose, use `python -m ab frames robin <anim> --only N`
followed by `python -m ab keep`, then copy the PNGs into `assets/sprites/robin/`.

## Scripting (cutscenes and the boss fight)

```gdscript
var robin := get_tree().get_first_node_in_group("robin")
robin.take_control()               # stops following, hints and warnings
robin.snap_to(spot)                # place instantly
await robin.fly_to(spot, 400.0)    # straight-line flight, emits `arrived`
robin.say("Swaminathan!", 2.0)     # speech bubble; works in any mode
robin.release_control()            # back to following Siya
```

The hypnotised state, the dizzy meter and the boss attacks are not built yet. They
should live in the boss script and drive Robin through this API, or swap in a
separate boss-Robin scene for the fight.

## Smooth movement on high refresh displays

Project physics interpolation fills the rendered frames between the 60 Hz physics
ticks. Siya, Robin and his speech bubble share that timing, and the course camera
follows in `_physics_process` after character movement. Keep movement and camera
transforms on the physics clock. After placing or teleporting a character, call
`reset_physics_interpolation()` so it does not streak across the screen. Robin's
initial placement, distance catch-up and `snap_to()` already do this.

For visual checks, run the forest at 200 FPS on a high refresh display, walk in
both directions through camera scrolling, reverse direction, dash, and read a
Robin hint while moving. Also check room transitions and respawns for streaks.
`tests/movement_check.gd` guards against camera movement during idle frames;
`tests/robin_check.gd` covers following, perching, hints and teleport catch-up.
