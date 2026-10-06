# Campaign finale

All three campaign showdowns keep their existing introductions, death animations
and aftermath dialogue. Defeating Khara, Dhoomketu or Swaminathan unlocks a pulsing
golden exit on the right and leaves Siya free to move. The palace gates open and
Raj joins Siya immediately after Swaminathan's defeat.

Walk into the glow to freeze the arena and close the existing curtain fabric.
Only after the curtains fully close does the aftermath dialogue appear. Closing
the final panel advances directly to the next campaign stage, or the Diwali
victory screen after Swaminathan. Robin's allegiance reveal and all other story
panels are preserved. Enter and hidden result controls cannot skip the walk.
Pausing suspends the curtain close; restarting or leaving discards the local
transition along with its scene.

The ending keeps the existing village backdrop, fireworks and approved Siya/Raj
sprites. Raj stays in his freed pose. Return to title, Start a new journey and
Replay the final showdown all use the existing navigation APIs. Escape or the
controller's back action returns to title. A new journey opens the prologue;
replaying the finale starts a fresh palace showdown with its introduction.

Developer snapshots and isolated boss arenas retain the shared boss result
buttons and their developer-menu routing. Boss attacks and death sequences
are unchanged.

## Persistence integration contract

This change adds no shared campaign state or disk writes. Arena `completed` and
`CampaignFlow.won` still mean the boss fight is won, not that the campaign escape
has finished. `PalaceEscape.unlocked` and `CampaignFlow._escape_ready` are local
scene state, set after the boss defeat. `CampaignFlow._transitioning` means
Siya entered the glow and the curtain/dialogue sequence has started.

Each `BossExit` calls `CampaignFlow.finish_escape()` for a living Siya inside its
area. This begins the curtain/dialogue sequence, not campaign completion. The
completion boundary is `CampaignFlow._change_destination()` after the palace
aftermath finishes, routing to `res://scenes/main/ending.tscn`. The save/load
thread can record campaign completion at that boundary and restore
completed saves to the ending. Loading the ending alone must not award completion:
it is also available through developer navigation. Starting a new journey should
use the same persistent reset contract as the title's New Game. Replay finale
should retain a previously earned completion while resetting the encounter.

## Validation

`campaign_flow_check.gd` exercises the campaign stage transitions, final hit,
death animation, real movement into all three exits, curtain-before-dialogue
ordering, pause/resume during closure, unchanged story panels, and each
victory-screen destination. `playtest_menu_check.gd` follows the finale route and
checks snapshot navigation. `cast_gameplay_check.gd` verifies Raj remains freed
at native art scale and that the result controls retain focus.

Validated with the existing Godot 4.7.2 installation at
`/home/sdixit/Downloads/Godot_v4.7.2-stable_linux.x86_64`: all 33 regression suites,
Linux smoke PCK export/launch, and the packed-resource check outside the project.
Native-window checks used an assisted boss defeat and dialogue advance, then
keyboard movement through the gates and ending navigation. This does not replace
a full human playthrough of the final boss or a physical-controller check.

Rendered captures: [forest exit](screenshots/ending/forest-exit.png),
[river exit](screenshots/ending/river-exit.png), [open palace gates](screenshots/ending/open-gates.png),
[curtain close](screenshots/ending/curtain-close.png), and
[victory screen](screenshots/ending/victory.png).
