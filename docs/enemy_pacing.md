# Enemy pacing pass

Branch `feat/level-enemy-pacing`, based on `82110e9`. This pass changes placements
only, using the existing guard, brute, shooter and flyer scenes and their approved
art. Enemy combat, movement, bosses, checkpoints, bridge repair and Robin are
unchanged.

| Level/area | Before | After | Added types |
| --- | ---: | ---: | --- |
| Forest main route | 8 | 16 | Seven guards, one low flyer |
| Forest root chamber | 2 | 3 | One guard |
| Forest canopy nest | 4 | 4 | None |
| Forest total | 14 | 23 | |
| River | 10 | 15 | Two guards, one shooter, one low flyer, one brute |
| Palace | 6 | 12 | Four guards, one low flyer, one brute |
| Campaign levels total | 30 | 50 | |

The requested increase guides pacing rather than doubling every fight. The
canopy nest already has four enemies around its climb and sentinel, and the
river bridge already has two repair guards, a shooter and a flyer. Those
encounters keep their existing composition. Palace gains its first flyer and
reaches twelve enemies; river grows more cautiously around its jumping and
bridge-repair sections.

## Placement choices

Coordinates give enemy feet, in level space.

- Forest: ClearingScout at `(1710, 430)` starts combat on the broad first clearing,
  before the existing guard. RidgeGuard at `(5645, 270)` occupies the ridge summit
  after the stairs. HollowExitGuard at `(8370, 430)` and BanyanExitGuard at
  `(11320, 430)` fill broad stretches near the hollow exit and banyan climb.
  UpperEntryGuard at `(13560, 430)` uses the upper section's entry floor before
  its narrow jumps. FinalScout at `(19040, 350)` flies 20 units above the second
  final platform, within grounded lash reach. FinalLowGuard at `(19810, 450)`
  and FinalExitGuard at `(20810, 430)` split the final stretch into separate
  landings. RootDescentGuard at `(1560, -1600)` adds a melee encounter on the
  third root-room descent, away from the arrival and local diya.
- River: DockGuard at `(1010, 390)` occupies the broad dock. GhatRestGuard at
  `(4910, 430)` uses the rest floor before its diya. GhatEntryShooter at
  `(5510, 430)` follows that safe pocket on the lower route before the stairs.
  ChannelScout at `(11540, 337)` flies 13 units above the first channel pier;
  it is grounded-lash reachable and does not cover the recovery docks.
  ProcessionBrute at `(13200, 430)` follows the existing procession guard on
  the broad court, clear of the crate and final diya.
- Palace: GateGuard at `(490, 430)` starts combat on the broad gate approach.
  GalleryEntranceGuard at `(3500, 430)` and GalleryExitGuard at `(4780, 430)`
  flank the existing shooter sequence. RoofLookoutScout at `(6360, 217)` is
  a low flyer over the lookout, before the broken-roof jumps. InnerEntryBrute
  at `(9100, 430)` and InnerHallGuard at `(10800, 430)` fill the inner court
  and hall on either side of the existing guard/shooter sequence.

Added enemies have short patrols and local detection ranges. Main-route diya
positions remain outside their initial patrol plus detection envelopes. Boss
entry and exit areas, jump geometry, recovery floors and optional upper routes
receive no new enemies. Ground enemies retain their shared edge probes and
bodies do not block Siya.

The existing checkpoint guard requires defeating every preceding encounter.
Added enemies therefore use the main route, rather than forcing a detour through
the gallery roof or river balcony. Existing gates automatically include the new
actors. More fights also mean more required combat before securing a diya; this
needs a sustained player run to judge fatigue and total damage pressure.

## Validation

`enemy_pacing_check.gd` runs actual patrol physics, checks support across each new
patrol, safe arrivals and diya envelopes, authored spawn markers, and grounded
zero-ammunition lash damage against every added enemy. It also rejects placements
on optional alternate-route floors. Existing level checks retain real traversal,
recovery, bridge repair, shooter cover, checkpoints and encounter isolation.

The forest finish regression now reloads terrain mode after toggling enemies;
the toggle applies during scene loading. This allows its finish/restart probes
to remain independent of the new final encounters.

Verified with the existing Godot `4.7.2.stable.official.ed1daf0bf` executable at
`/home/sdixit/Downloads/Godot_v4.7.2-stable_linux.x86_64`, set as `GODOT_BIN`.
The final full runner passed **34/34 suites**. Smoke import/export and the
headless pack launch passed; the resource check passed all **19 packed scenes**
from outside the project. `git diff --check` passed.

Six graphical encounter captures were inspected across all three levels,
including the river shooter/brute and palace flyer. This was rendered visual QA,
not a complete manual gameplay run. A full manual campaign playthrough remains
unverified, particularly cumulative damage and the extra combat before diyas.
Generated `.godot/` and `builds/` output is ignored and excluded from the change.
