# Forest traversal draft

The level order is forest, river/ghats, temple/palace. F5 starts the forest.
This revision expands the route from 7,200 to 21,600 pixels and removes the
forest silhouettes, moss, water colours and lantern decoration. Terrain is
grey editable Godot scene geometry. Player movement values are unchanged.
Existing player dash/hurt feedback is still shared with the tuning scenes.

## Route and difficulty

| Section | World X | Terrain challenge |
| --- | --- | --- |
| Forest edge | 40-1600 | Two 40 px root climbs, a descent and two short gaps |
| First clearing | 1600-2800 | Encounter space and the first manual diya |
| Broken canopy | 2800-4800 | Staggered branch jumps, 120-180 px landings, then a 220 px dash gap |
| Root ridge | 4800-6500 | Four 40 px climbs to Y=270, followed by descending gap jumps |
| Hollow trunks | 6500-8900 | Two low roofs, a raised takeoff, then 200/230 px dash gaps |
| Stone crossing | 8900-11200 | 100-180 px platforms and mixed 100-220 px gaps; brake between jumps |
| Banyan climb | 11200-13600 | Five stacked jump-through branches, alternating right and left, then a descending dash chain |
| Upper ravine | 13600-16100 | 180-220 px gaps with higher and lower landing platforms |
| Old shrine | 16100-18400 | Three 40 px climbs, elevated crossings, and a descent to a clearing |
| Last crossing | 18400-21000 | Seven narrow landings across 200-230 px gaps, with changing elevation |
| River approach | 21000-21560 | Final 100 px jump and the exit flag |

There are 59 main-route platforms. Most challenge sections have open pits,
so failed jumps return to the last secured diya. The original catch paths
and easy lower bypass are removed. The fixed camera includes all required
platforms between Y=230 and Y=450. Land before trying another dash.
The banyan branches use Godot one-way collisions, so jumping upwards through
an overhead branch is possible; they support Siya when she descends.

## Entered forest sections

Press E at the door on the root ridge, X=5660, Y=270, to enter the root
chamber. It descends through three separated root shelves to a broad bed,
then climbs twelve 40 px steps to the far return door. Its local diya is
on the bed before the ascent.

Press E at the door on the banyan's top branch, X=11730, Y=230, to enter
the canopy nest. Climb 24 alternating jump-through branches, rest at the
crown, and cross three outer branch connections to the nest. There are
local diyas halfway up the trunk and at the crown. The camera follows
vertically inside these rooms and restores the forest framing on return.

The far door completes a section and returns to the same forest entrance.
The entrance door lets you leave early. Death stays inside the entered room
at its last local diya or entrance. Local saves do not replace the forest
diya. Completed entrances show `CLEARED`, and can be entered again.
R clears the entire run, including room saves and completion indicators.
The rooms are isolated geometry under `SideRooms` in the forest scene.

RootGuard, CrownGuard and NestBoss markers reserve encounter positions.
The nest's future boss is optional; no boss controller is assumed.
See [the footage and map review](guacamelee_research.md) for sources,
observations and the limits of the research.

## Manual diya checkpoints

Press E within range while grounded and in normal movement to light a diya.
The world prompt reads `E: light diya` while interaction is available, then
`SAVED`. Passing a diya, holding E before entering range, dashing or pressing
E while airborne does not activate it. Only explicitly lit diyas show flames.

Diyas are at X=2450, 4590, 6800, 8650, 11000, 13350, 15950 and 18100.
Death reloads at the furthest lit diya with full health and fresh movement
state. Lighting an earlier diya does not rewind progress. R resets all saved
positions and lit indicators. Saves last for the current run, not across app
launches. Finishing reaches the river destination; the next level is pending.

## Enemy handoff

The level's `EncounterSpawns` Marker2D nodes are on flat safe ground:

| Marker | X | Intended use |
| --- | --- | --- |
| ClearingGuard | 2200 | Introduce one enemy before the broken canopy |
| HollowGuard | 6600 | Encounter after the ridge descent |
| StoneGuard | 8470 | Encounter before the narrow stepping stones |
| BanyanGuard | 10700 | Encounter before the vertical climb |
| UpperGuard | 13200 | Encounter before the upper ravine |
| ShrineGuard | 15770 | First shrine enemy |
| ShrineRearGuard | 16150 | Optional second shrine enemy after combat tuning |
| FinalGuard | 17850 | Final encounter before the dash chain |

The incoming enemy's collider, attack ranges and defeat signals still need
inspection before placement. Keep pursuit inside each clearing and away
from pit takeoffs and diya interaction zones. No enemy behaviour or gate
system is assumed. The enemy-free exit remains available for traversal tests.

## Validation

`tests/forest_check.gd` runs real Godot collisions across every consecutive
route connection. It probes normal jumping and dash timing with different
takeoff positions, and checks landing/recharge on the actual geometry.
These isolated probes establish reachability; they do not prove that players
will recognise the right timing or enjoy a continuous run.

The check also tests all checkpoint spawn floors, no automatic activation,
physical E input, holding E while approaching, airborne rejection, visible
activation, skipped-diya state, death recovery, completion and R reset.
Run it alongside movement, dash, combat and course checks.

The next manual playtest should record failed jump locations, whether small
landings give enough braking room, whether the jump-through branches read
clearly, and whether checkpoint spacing is too punishing. Do not infer a
first-play completion time from the route length.

## Reference principles

[Jason Canam's Guacamelee design notes](https://www.gamedeveloper.com/design/building-a-house-for-the-devil-designing-guacamelee-s-dlc)
informed focused ability challenges and the alternation of traversal with
encounter space. This revision increases required-route difficulty at the
user's request. It uses the current jump and dash, without requiring wall
jumps, uppercuts, world switching or other unavailable abilities.
