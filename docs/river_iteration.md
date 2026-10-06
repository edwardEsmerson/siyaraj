# River and ghats iteration

The 14,400-pixel river route now alternates crossings, combat landings and recovery stretches. It uses the existing player, weapons and four enemy types; movement settings are unchanged. Geometry is editable grey native Godot nodes in `scenes/levels/river.tscn`.

| Stretch | Main decision | Recovery or alternative |
| --- | --- | --- |
| Ferry landing | Cross broken docks, then approach a guard from a broad landing. A crate offers a jump-over approach. | A lower dock catches a missed jump and has a two-step exit. |
| Stone fords | Climb the stones and confront a guard on a wide central stone. | Take the lower dock and climb back onto the final ford. |
| Ghat courtyard | Climb the stairs and duel a brute on a wide upper court. | Turn back from the third step, climb the one-way balconies, and descend beyond the brute. |
| Broken bridge | Close on a shooter behind a crate, collect four boards with E from the lower approach, fight two guards on the stairs and deck while carrying each board, and place it with E at the growing edge. Finish with jump + dash to the flyer landing. | Supplies sit 386–440 units back from the initial edge. Four 60-unit boards reduce the 480-unit opening to 240 units. The restored air-dash carry makes a three-board 300-unit gap unreachable and the four-board gap reachable. Lower shelves catch falls; built boards survive death, and a new run resets the puzzle. |
| Aqueduct | Cross into a shooter/brute pocket. Crates break sight and stop shots. Ground dash, lash and chakri all fit on the broad floor. | Recover at the next diya before the channel piers; lower piers catch missed jumps. |
| Temple procession | Fight a final guard, secure the last diya, then climb to the palace entrance. | A long landing separates the last enemy from the checkpoint and final ascent. |

The five existing checkpoint positions remain intact for menu section launches: x=2630, 5300, 7900, 10950 and 13500. The carried board inherits Siya's interpolated transform, so it stays aligned with her between physics ticks on high refresh screens. Lighting still requires a fresh grounded E press. All ten encounters stay outside the checkpoints' detection and patrol reach. Skyshot ammunition is optional. With encounters enabled, each diya requires
its preceding enemies to be defeated; terrain-only runs bypass those guards.

`Terrain` contains 35 ordered primary platforms. `AlternateRoutes` contains 14 recovery/balcony platforms. `Cover` contains five 40-pixel crates, within the unchanged jump height. `EncounterSpawns` mirrors the ten authored encounter placements. The river adds no swimming, wall climbing or new player abilities. Its exit
opens Dhoomketu's separate ghats showdown before the palace.

Run `godot --headless --fixed-fps 60 --path . --script res://tests/bridge_planks_check.gd` for pickup, placement, gap traversal and reload checks. Run `godot --headless --fixed-fps 60 --path . --script res://tests/river_design_check.gd`. This traverses all 35 primary connections after repairing the bridge and 16 alternative connections with the actual controller, tests a missed-jump landing, checks manual diyas and encounter placement, fires real skyshots into cover and along an open lane, lashes the flyer with zero ammunition, and dashes along the aqueduct with invulnerability active. Rendered checks inspected the ghat courtyard, broken bridge and aqueduct. These checks establish reachability and combat affordances; full continuous pacing still needs human playtests.
