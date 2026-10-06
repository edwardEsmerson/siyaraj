# Level iteration brief and integration

The refined brief for this pass was: have separate agents redesign the forest,
river and palace around the game's current movement, traversal, weapons, enemies
and bosses. Give each level a distinct identity, varied routes and pacing, and
encounters shaped by the terrain. Keep everything grey and editable, preserve
playtest access, then integrate and validate all three revisions.

Each agent worked in a separate Git worktree. The combined result lives on
`feat/level-design`; the primary checkout remains on `main`. Each level has one
revised version. These are separate design contributions, not extra campaign
variants.

## Design intent

- Forest uses vertical exploration, detours with enemy challenges, low recovery
  routes and mixed encounters before the Khara clearing. Canopy encounters use
  reachable heights, so ammunition is an option rather than an entry requirement.
- River alternates long combat islands, ghat climbs and exposed crossings. Lower
  recovery shelves and cover give ways to approach ranged threats and recover
  from some missed jumps. It leads into the palace without adding another boss.
- Palace uses broad courtyards, pillars, covered approach lanes and optional upper
  routes. Climbs and descending roofs lead into a safe Ravan approach.

Read the level-specific design notes for exact routes and encounter placements.
All use the existing movement and weapons without changing their tuning.

## Campaign progression

The forest and palace exit panels offer Enter to face their boss. The showdowns
inherit the original boss arenas, so the actors, tells, hazards, phase behavior
and arena dimensions match the existing tested fights. The campaign wrappers
change grey scenery and attach victory navigation. No boss moves were rewritten.

Khara victory leads to the river. River completion leads to the palace. Ravan
victory finishes the run and returns to level select. Fights start with the
arena's full-health loadout, five shots and ready chakri. Khara retains the
three-health player; Ravan retains his original five-health arena player.
Death reloads the fight, not the whole traversal level. R repeats the fight.
Esc pauses or returns to the menu. There is no disk save or cumulative run timer.

Terrain-only menu launches remove encounters and bypass the bosses. Developer
snapshots retain the original boss arenas and add campaign showdown presets.
Victory in a showdown snapshot returns to the menu.

## Validation

The level tests exercise consecutive route connections, alternate routes, actual
cover and melee interactions, checkpoint safety and manual saving. Campaign flow
checks verify explicit entry, living-boss gates, death retries, real defeat signals
and progression. The original boss suites still verify combat and phase behavior.
Rendered inspection checks the grey levels, menu and boss/victory HUDs.

Passing route probes establishes reachability with the current controller. It
does not establish human pacing or difficulty. Play the revised routes continuously
to decide which optional paths, encounter timings and checkpoint intervals feel best.
