# Forest iteration

The forest remains a 21,600px grey course with native editable platforms. Movement, weapon, enemy and boss tuning are unchanged. Its trail leads to the separate Khara showdown through the campaign integration.

The main route alternates traversal with eight enemies. The first guard introduces dash-through and lash recovery. The broad branch after the broken canopy has a low scout that can be lashed from the ground. The hollow shooter occupies a covered floor, so ground dash and charge interruption matter more than jumping. The banyan keeps its original shooter and isolated climb entrance. A wider upper branch gives space to fight another scout. The shrine has a brute followed by a guard, and the last approach has a guard before the final diya.

The last crossing rises to a crown, descends into a low ravine and climbs back out. Catch roots below the stone and upper ravine crossings let a missed landing become a recovery climb. The ledges above those roots are one-way, so Siya can climb through them rather than hit their underside. These roots do not remove the remaining falls.

The canopy changes branch lanes twice and has two broad boughs occupied by guards. Its nest has a sentinel and a low flying enemy. Both flying enemy placements remain reachable with unlimited grounded lash; spending a skyshot is a choice. The root chamber has its shooter plus an exit sentinel. Defeating each far-door sentinel opens that room's return portal. Entrance doors still allow leaving an unfinished room, and completed-room markers remain on the trail. The enemies-off playtest setting removes sentinels and opens both exits.

There are nine main diyas, including `KharaDiya` at `(21200, 430)`. Side rooms keep separate saves and transport preserves health, ammo and weapon cooldowns. Death restores the last explicitly lit diya and a fresh player. Lighting a fresh diya restores one heart, capped at maximum health, without refilling weapons. Already lit diyas and side-room diyas do not heal.

## Checks

Run the existing forest, forest rooms, forest encounters and forest weapons suites. `tests/forest_iteration_check.gd` adds real physics checks for both recovery climbs and their route connections, final-diya death respawn, and grounded melee kills against all three flying placements with zero skyshot ammo.

The individual main-route and room-route connections have been checked with real physics. Representative upper-ravine, canopy and clearing views have been rendered and inspected. Continuous human playtests are still needed to judge pacing, pressure and replay length.
