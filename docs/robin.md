# Robin

Robin is Siya's bird companion: `scenes/companions/robin.tscn` with
`scripts/companions/robin.gd`. He is in the forest, river and palace level scenes.
He has no collision and he never deals or takes damage. The Robin strike was cut,
so he is a guide only.

## What he does

- **Follows** Siya, hovering behind her head and mirroring her facing. He flies on a
  spring, so dashes pull him along quickly. After a long jump (a room change or a
  respawn) he snaps straight to her.
- **Perches** on Siya's head after she stands still for 2 seconds. If she stays
  still for longer he makes an idle comment. He takes off as soon as she moves.
- **Points out hints.** Each `RobinHint` area in a level sends him to a spot to
  explain something there. A hint shows once per session, and death reloads do not
  repeat it.
- **Warns** once about each live enemy that comes within 260 px of Siya. An enemy
  that a hint already covers does not get a second warning.
- **Reacts** when Siya takes damage or goes down. The lines are in `Robin.LINES`;
  edit them freely.

## Adding hints

Instance `scenes/companions/robin_hint.tscn` in a level and set its `text`. The
trigger is a tall 64x480 column above the node, and its shape is local to each
instance, so it can be resized in the editor. `point` is where Robin hovers, relative
to the hint. The forest's hints are under `RobinHints` in `scenes/levels/forest.tscn`.
The river and palace have no hints yet.

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
