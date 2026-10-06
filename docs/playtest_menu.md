# Playtest menu and next level drafts

Run the project with F5 to open the title screen, then choose Playtest menu (shown
in debug builds only). F6 still runs the current scene directly.

Select Forest, River and ghats, or Temple and palace. Choose Beginning or a named
checkpoint section, then Play selected level. New launches reset that level's
session progress. Turn off Enable enemy encounters to focus on traversal.
Checkpoints require a fresh E press while grounded beside a diya. Death restores
the last checkpoint with full health and weapon resources. R resets the level.

Esc pauses any level or standalone playground. Resume, go back to the last lit
diya, restart, change settings, quit to the title, or (debug builds) return to
level select. Time and gameplay stop while paused. Finishing the forest or river
offers Enter to advance to the next level. Finishing the palace offers Enter to
face Ravan; defeating Ravan and pressing Enter opens the ending screen.

## Developer snapshots

The lower selector opens repeatable test scenes using the team's existing
controllers and tuning resources:

| Snapshot | What to test |
| --- | --- |
| Weapons | Lash, skyshot ammunition and recoil, charged chakri and cooldown (`scenes/dev/weapons_playground.tscn`) |
| Character movement | Running, stopping, jumping, ground and air dash, collisions |
| Brute | Dev sandbox preset: large melee enemy tells, reach, damage and knockback |
| Ground shooter | Dev sandbox preset: charge interruption, homing shots and evasion |
| Flying enemy | Dev sandbox preset: aimed shots and jumping melee |
| Melee guard | Dev sandbox preset: chase, attack timing and protection |
| Dev sandbox | `scenes/dev/sandbox.tscn` with the encounter and loadout chosen on its root in the inspector |
| Khara arena | Boss 1: gada slam shockwave, ladi firecrackers and enrage (`scenes/bosses/khara_arena.tscn`) |
| Ravan arena | Boss 2: lunging heads, regrowth, amrit window and Dashanan Fury (`scenes/bosses/ravan/ravan_arena.tscn`) |
| Original combat course | Traversal, combat and exit unlock |
| Terrain sampler | Stairs, narrow tops, dash gaps and descending landings |
| River stepping stones | Actual river route starting at the ferry checkpoint |
| Palace gallery and roofs | Actual palace route starting below the gallery climb |
| Canopy climb | Forest nest room, alternating branches, local diyas and return door |

The four enemy snapshots open the one dev sandbox with that enemy preselected
(through `Sandbox.next_encounter`, which survives R and death reloads); the
Dev sandbox entry clears that preset so the inspector choice applies.
Snapshots are listed once, in the `SNAPSHOTS` table in
`scripts/main/playtest_menu.gd`; the selector is filled from it at runtime.
Add a row there (and to the smoke export list in `export_presets.cfg`) to
register a new snapshot.

Terrain and canopy snapshots omit encounters. Pause-menu restart repeats the
chosen snapshot, including the sandbox preset. R also repeats terrain and canopy snapshots. Other playgrounds
retain their own R behavior. No extra playable character exists yet; the character
snapshot uses the current Siya controller. Snapshots are launch presets, not
copies of gameplay scripts, so friends' controller updates apply to them too.

## Editable drafts

Both new full levels span 14,400 pixels, with five manual checkpoints and three
draft encounters each. River has 37 route platforms covering docks, stepping
stones, ghat steps, high piers, a broken bridge and the temple approach. Palace
has 43 platforms covering the gate, pillar court, gallery stairs, roof descent,
terraces, sanctum ascent and throne landing. The compact terrain sampler has
13 platforms and two diyas over 4,200 pixels.

Edit the native scenes under `scenes/levels/`. Each route platform has
`metadata/route_order`; `Checkpoints`, `Encounters`, and `EncounterSpawns` are
separate editable groups. Grey river water is a fall zone, with no swimming
mechanic. These are first traversal and encounter drafts; art, moving terrain,
bosses and encounter gates remain future design work.

`scripts/levels/draft_level.gd` shares checkpoint behavior between these drafts.
`scripts/main/playtest_navigation.gd` owns pausing and snapshot launches; the pause
menu itself is `scenes/ui/pause_menu.tscn`. Main HUD
and weapons use the same scripts as the forest. No movement values changed.

Validate with `tests/next_levels_check.gd` and `tests/playtest_menu_check.gd` in
addition to the existing regression suites. The route checks exercise each
consecutive landing using real player physics. Continuous playtesting is still
needed to judge pacing and difficulty.
