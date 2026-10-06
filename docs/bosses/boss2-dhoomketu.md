# Dhoomketu, the Firework Commander

Dhoomketu is an original Diwali villain for Siyaraj. He has commandeered a
fireworks barge moored at the ghats and blocks the route to the palace.
His plum coat, brass firework bandolier and shoulder rocket rack distinguish
him from Khara's gada and ladi arsenal. Diyas, bunting and rocket crates dress
the arena. Dhoomketu uses generated sprite art (`assets/sprites/dhoomketu/`, source `asset-builder/sprites/dhoomketu/`) on a `Visual/Art` AnimatedSprite2D at scale 0.5; the barge is still scene placeholder art.

The level 2 exit opens `scenes/main/river_showdown.tscn`. Defeating Dhoomketu
opens the palace and Swaminathan's finale. Death retries this fight with fresh health
and weapons. Terrain-only launches bypass it. The developer menu offers his
isolated arena and the ghats campaign showdown.

## Attacks and counters

| Attack | Warning and behavior | Counter |
| --- | --- | --- |
| Rocket salvo | Three pink dashed flight paths lock before launch. Rockets fire 0.28 s apart, fly diagonally at 340 px/s and stop at solid walls or floor. | Leave the marked paths before launch. Rockets do not home. |
| Chakri chase | A gold ground arrow warns of a rolling 16 px high spinner. It travels at 220 px/s for 2.5 s and can bounce once at the deck edge. | Jump over it or dash through it. Watch for the bounce. |
| Anaar fountains | Two 48 px wide gold lanes lock beside Siya, 140 px apart. Conical fireworks burn 110 px high for 1.25 s after their fuses expire. | Walk out of the marks and use the gap between fountains. |

The cycle is rockets, chakri, anaar. A 0.9 s fuse precedes each attack.
Recovery begins after all hazards in the attack expire, lasts 1.4 s and reads
"RELOADING - STRIKE NOW". All player weapons can damage Dhoomketu throughout
the fight. He has 28 health, no contact damage and no knockback movement.
Each hazard deals one damage through `take_damage` and hits a player at most
once. Dash and hurt protection apply. Rockets disappear on a damaging hit.

At half health, Dhoomketu clears hazards and pauses for 1.2 s to "LIGHT EVERY
FUSE!" Phase 2 uses four staggered rockets, a faster chakri plus a delayed
spinner from the opposite edge, and three anaar lanes. Fuses shorten to
0.765 s; recovery keeps its full duration. Defeat disables the boss body and
clears hazards before campaign victory appears.

The boss uses the generic health bar and shared arena/restart scripts.
Tune health, warning, recovery, rocket speed/stagger, chakri speed and fountain
burn duration on `scenes/bosses/dhoomketu.tscn`. The isolated arena is
`scenes/bosses/dhoomketu_arena.tscn`. Hazard coordinates assume its 960 px deck
and local origin, with chakri turn points at x=50 and x=910.

## Validation

`tests/dhoomketu_check.gd` checks actual lash, skyshot and charged chakri damage,
staggered locked rocket aim, diagonal rocket hits, solid-wall impacts, anaar
warnings and escape lanes, one hit per fountain, normal jump clearance,
chakri bounce, dash immunity, phase changes, all three phase 2 attacks,
shared health bar, hazard cleanup, the autonomous cycle and safe recovery.
Campaign and menu checks cover launch, retry, victory, advancement and terrain
bypass. The export list includes the hazard script for packed-game launches.

Manual playtesting is still needed to judge rocket warning readability, the
second-phase chakri timing and counterattack opportunities with all weapons.

Godot 4.7.2 verification passes the boss, campaign and developer menu checks.
The smoke pack exports and the packed ghats showdown launches without script
errors. The full regression run also reproduces failures in unchanged movement
routes in `dash_check.gd`, `forest_check.gd`, `forest_rooms_check.gd` and
`next_levels_check.gd`. `course_check.gd` fails its dash-gap assertions, accesses
a freed scene and times out. Those routes need separate movement work.
