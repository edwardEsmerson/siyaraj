# Forest traversal history

For the current route, encounters, recovery paths and guarded detours, read
[forest iteration](forest_iteration.md). F5 opens the playtest menu. The forest
exit now offers Khara's campaign showdown; see [level integration](level_iteration.md).
The notes below describe the earlier traversal draft and its original design decisions.

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
| Broken canopy | 2800-4800 | Staggered branch jumps, 120-202 px landings, then a 198 px dash gap |
| Root ridge | 4800-6500 | Four 40 px climbs to Y=270, followed by descending gap jumps |
| Hollow trunks | 6500-8900 | Two low roofs, a raised takeoff, then 200/207 px dash gaps |
| Stone crossing | 8900-11200 | 120-180 px platforms and mixed 100-198 px gaps; brake between jumps |
| Banyan climb | 11200-13600 | Five stacked jump-through branches, alternating right and left, then a descending dash chain |
| Upper ravine | 13600-16100 | 90-198 px gaps with higher and lower landing platforms |
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

On the main trail, all enemies authored before a diya must be defeated before
it can be lit or passed freely. Siya can travel 120 game pixels past an
uncleared diya before the return triggers, including during a jump or dash.
Exceeding that leeway closes red curtains over 0.45 seconds. Their top edges
lead the pull, with the curved lower edges trailing and settling after the
top reaches the middle.
While fully covered, Siya is moved to the uncleared diya she just passed.
This does not light it or advance the saved death checkpoint. The curtains
hold for 0.5 seconds and open over 0.45 seconds with the same delayed hem
motion. Health, ammo, saved progress and enemy
damage remain unchanged. Gameplay stops during the transition; Esc also
pauses the curtains.
The same rule applies to river and palace checkpoints. Enemy-free developer
launches bypass it, and section snapshots start their requirements at the
selected landing. Death reloads do not re-block a secured respawn with enemies
behind it. Side rooms retain their separate sentinel-controlled exits.

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

The first integrated pass uses the guard at X=2050, ground shooter at
X=10650, Brute at X=15700, and a shorter-range shooter at X=2200 in the
root chamber's local coordinates. Enemy roots and their patrol detection
envelopes start outside the secured diya respawn positions. Projectiles
already fired can still reach a player moving toward a diya.

Only the current area's enemies are instantiated. Room transitions and
death reloads restore enemies with full health. The nest remains empty
until its encounter is designed. Main-route diyas now require clearing the
preceding enemies. Side-room far exits require their sentinels, while entrance doors allow leaving early.
The original prototype keeps its guard-controlled gate and both new enemies.
The flying enemy already merged on GitHub is also available in that prototype
and the dev sandbox. Terrain remains grey; enemy attack feedback uses
the shared combat scenes.

## Weapon integration

The forest player scene inherits the shared movement scene and uses the
weapon PR's controller and single-lash component. J attacks on the ground
or in the air. L fires a two-damage skyshot with recoil, consuming one of
five shots. Holding K for one second and releasing produces a full chakri
spin for three damage; a shorter charge produces a smaller, weaker spin.
Chakri has a 10-second cooldown. The bottom-right orange circle drains with
skyshot ammunition; the blue circle refills as Chakri recharges.

Door transitions preserve current health, ammunition, chakri cooldown and
shot recovery. Entering or leaving an optional room cannot refill weapons
or heal Siya. Lighting a diya also leaves these values alone. Death and R
restore the loadout, health and cooldowns at the appropriate saved position.
The weapons playground (`scenes/dev/`) remains available with F6, and the original
prototype/tuning scenes continue using their original player controller.

`forest_weapons_check.gd` fires through physical L input at a real forest
guard, finishes it with J, charges chakri against the Brute, checks the HUD,
and exercises diya interaction, room entry/exit and death recovery.

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

`forest_rooms_check.gd` checks every detour connection, local save/recovery,
door completion, leaving early and R from a room. `forest_encounters_check.gd`
checks active-area isolation, enemy floors, damage and initial patrol spacing
from diyas. Terrain probes freeze enemy controllers so combat cannot hide
a failed jump. The independent enemy suites exercise their actual attacks.

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
