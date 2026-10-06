# River and ghats iteration

The 14,400-pixel river route now alternates crossings, combat landings and recovery stretches. It uses the existing player, weapons and four enemy types; movement settings are unchanged. Geometry is editable grey native Godot nodes in `scenes/levels/river.tscn`.

| Stretch | Main decision | Recovery or alternative |
| --- | --- | --- |
| Ferry landing | Cross broken docks, then approach a guard from a broad landing. A crate offers a jump-over approach. | A lower dock catches a missed jump and has a two-step exit. |
| Stone fords | Climb the stones and confront a guard on a wide central stone. | Take the lower dock and climb back onto the final ford. |
| Ghat courtyard | Climb the stairs and duel a brute on a wide upper court. | Turn back from the third step, climb the one-way balconies, and descend beyond the brute. |
| Broken bridge | Close on a shooter behind a crate, then cross the elevated bridge and deal with a low flyer. | Lower shelves catch bridge falls; the flyer is lash reachable with no ammunition. |
| Aqueduct | Cross into a shooter/brute pocket. Crates break sight and stop shots. Ground dash, lash and chakri all fit on the broad floor. | Recover at the next diya before the channel piers; lower piers catch missed jumps. |
| Temple procession | Fight a final guard, secure the last diya, then climb to the palace entrance. | A long landing separates the last enemy from the checkpoint and final ascent. |

The five existing checkpoint positions remain intact for menu section launches: x=2630, 5300, 7900, 10950 and 13500. Lighting still requires a fresh grounded E press. All eight encounters stay outside the checkpoints' detection and patrol reach. No enemy kill or skyshot ammunition is required to finish the river.

`Terrain` contains 35 ordered primary platforms. `AlternateRoutes` contains 14 recovery/balcony platforms. `Cover` contains five 40-pixel crates, within the unchanged jump height. `EncounterSpawns` mirrors the eight authored encounter placements. The river does not add a boss, swimming, wall climbing or new player abilities.

Run `godot --headless --fixed-fps 60 --path . --script res://tests/river_design_check.gd`. This traverses all 34 primary and 16 alternative connections with the actual controller, tests a missed-jump landing, checks manual diyas and encounter placement, fires real skyshots into cover and along an open lane, lashes the flyer with zero ammunition, and dashes along the aqueduct with invulnerability active. Rendered checks inspected the ghat courtyard, broken bridge and aqueduct. These checks establish reachability and combat affordances; full continuous pacing still needs human playtests.
