# Palace and victory fireworks

The palace reuses `scripts/effects/fireworks.gd`, the title's code-drawn rockets,
flashes and square sparks. No new gameplay art, particles, shaders or audio are
added. One screen-fixed `Parallax2D` sits between WorldSkin's far sky and mid
architecture at z -95. Its clipped sky band is y 116 to 230; terrain, actors,
hazards and the HUD draw in front. Rockets launch every 2.4 to 3.6 seconds at
65% of the title effect's size and 45% opacity.

The integrated ending already had moving fireworks. Its existing `Fireworks`
node now instances `scenes/effects/victory_fireworks.tscn`, which confines the
same effect to two 130-pixel side areas below the heading. The skyline still
draws in front. The centered reunion text, characters and result buttons stay
clear of sparks. The palace escape, aftermath dialogue, navigation, audio and
settings APIs are unchanged. Shared boss result screens remain unchanged.

Effects inherit pause behavior. Hiding an effect or its parent stops processing
and clears its rockets, sparks and flashes. Showing it restarts the launch wait.
All animation state belongs to its scene node and clears when it leaves the tree;
there are no timers, detached particles or global effect owners.

`tests/fireworks_check.gd` checks two minutes of particle bounds, actual bursts,
pause/visibility behavior, camera scrolling, text/button clearance, focus and
scene-change cleanup. The existing campaign checks cover the final escape and
all ending destinations.

Native Compatibility captures show the [palace gates](screenshots/fireworks/palace-gates.png),
[palace roofs](screenshots/fireworks/palace-roofs.png) and
[victory screen](screenshots/fireworks/victory.png). Palace captures use assisted
camera positions and seeded bursts for review. They are visual inspection, not
a complete human playthrough or a performance benchmark on minimum hardware.

Validation used the existing Godot 4.7.2 executable at
`/home/sdixit/Downloads/Godot_v4.7.2-stable_linux.x86_64` with `GODOT_BIN` set.
The fireworks check passes, including the final camera probe. The full
`python tools/run_checks.py` run passes 36 of 37 suites. `robin_check.gd` fails
six tutorial/combat assertions; the identical six failures were reproduced in a
temporary untouched checkout of starting commit
`6b15432386585ca109f5ab8b5d50a14f7f274d0b`. That checkout was removed afterward.
The campaign, palace, menus, audio and world-skin checks pass.

The Linux smoke PCK exports and launches outside the repository. The external
packed-resource check passes all 19 scenes, including the palace and ending.
Generated `.godot/` and `builds/` output is excluded from the change.
