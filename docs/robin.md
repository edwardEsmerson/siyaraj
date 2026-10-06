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

Put the final art in `Visuals/Sprite`, an `AnimatedSprite2D` at scale 0.5 (1 game
unit = 2 art px). Give it `SpriteFrames` with `fly` and `perch` animations, plus the
optional `talk` and `point`. When frames are present, the placeholder polygons hide
themselves. Draw the sprite facing right, because `Visuals` is mirrored for left.

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
