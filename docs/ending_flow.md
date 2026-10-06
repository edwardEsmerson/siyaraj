# Campaign finale

The palace showdown keeps the existing introduction, final boss death animation,
Raj cage release and all ten aftermath panels, including Robin's allegiance
reveal. After the reader closes the dialogue, the palace gates open and Raj
joins Siya on the floor. Walk right through the gates to reach the Diwali
victory screen. Enter and the hidden boss result button cannot skip this walk.

The ending keeps the existing village backdrop, fireworks and approved Siya/Raj
sprites. Raj stays in his freed pose. Return to title, Start a new journey and
Replay the final showdown all use the existing navigation APIs. Escape or the
controller's back action returns to title. A new journey opens the prologue;
replaying the finale starts a fresh palace showdown with its introduction.

Developer snapshots and isolated boss arenas retain the shared boss result
buttons and their developer-menu routing. Other boss defeat sequences are
unchanged.

## Persistence integration contract

This change adds no shared campaign state or disk writes. Arena `completed` and
`CampaignFlow.won` still mean the boss fight is won, not that the campaign escape
has finished. `PalaceEscape.unlocked` and `CampaignFlow._escape_ready` are local
scene state, set only after the final dialogue closes.

The campaign completion boundary is `CampaignFlow.finish_escape()`, called by
the palace exit for a living Siya. It routes to `res://scenes/main/ending.tscn`.
The save/load thread can record campaign completion at that boundary and restore
completed saves to the ending. Loading the ending alone must not award completion:
it is also available through developer navigation. Starting a new journey should
use the same persistent reset contract as the title's New Game. Replay finale
should retain a previously earned completion while resetting the encounter.

## Validation

`campaign_flow_check.gd` exercises the campaign stage transitions, final hit,
death animation, dialogue ordering, gate traversal with real movement, and each
victory-screen destination. `playtest_menu_check.gd` follows the finale route and
checks snapshot navigation. `cast_gameplay_check.gd` verifies Raj remains freed
at native art scale and that the result controls retain focus.

Validated with the existing Godot 4.7.2 installation at
`/home/sdixit/Downloads/Godot_v4.7.2-stable_linux.x86_64`: all 33 regression suites,
Linux smoke PCK export/launch, and the packed-resource check outside the project.
Native-window checks used an assisted boss defeat and dialogue advance, then
keyboard movement through the gates and ending navigation. This does not replace
a full human playthrough of the final boss or a physical-controller check.

Rendered captures: [open gates](screenshots/ending/open-gates.png) and
[victory screen](screenshots/ending/victory.png).
