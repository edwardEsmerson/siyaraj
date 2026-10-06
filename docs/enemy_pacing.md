# Enemy pacing pass

The first pass was `feat/level-enemy-pacing`, based on `82110e9`. The doubling
follow-up is `feat/level-enemy-pacing-double`, based on current main `6b15432`.
This pass changes placements
only, using the existing guard, brute, shooter and flyer scenes and their approved
art. Enemy combat, movement, bosses, checkpoints, bridge repair and Robin are
unchanged.

| Level/area | Original baseline | First PR pass | Final count |
| --- | ---: | ---: | ---: |
| Forest main route | 8 | 16 | 34 |
| Forest root chamber | 2 | 3 | 6 |
| Forest canopy nest | 4 | 4 | 6 |
| Forest total | 14 | 23 | 46 |
| River | 10 | 15 | 30 |
| Palace | 6 | 12 | 24 |
| Campaign levels total | 30 | 50 | 100 |

The follow-up doubles the first PR pass exactly, adding 23 forest, 15 river and
12 palace enemies. It fills empty route sections and adds short, staggered
patrols to existing courts. Smaller landings use 10–25 unit patrol radii and
80–130 unit detection ranges to leave room for the approach and retreat. Enemy
health, attacks and their shared behavior are unchanged.

Final encounter counts between successive main-route diyas are:

| Level | Counts in checkpoint order |
| --- | --- |
| Forest | 4, 4, 4, 4, 4, 3, 4, 3, 4 |
| River | 6, 7, 6, 6, 5 |
| Palace | 5, 5, 5, 7, 2 |

Palace weights the broad inner courts more heavily while leaving its final
sanctum climb and boss approach less crowded.

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
entry and exit areas, jump geometry, recovery floors and optional alternate
routes remain unchanged. Raised main-route landings now have more encounters. Ground enemies retain their shared edge probes and
bodies do not block Siya.

The existing checkpoint guard requires defeating every preceding encounter.
Added enemies therefore use the main route, rather than forcing a detour through
the gallery roof or river balcony. Existing gates automatically include the new
actors. More fights also mean more required combat before securing a diya; this
needs a sustained player run to judge fatigue and total damage pressure.

## Doubling pass placements

The first-pass placements above remain. The new placements below distribute the
extra enemies through earlier empty platforms and between existing encounters.
Main-route stages receive the encounters, so the existing checkpoint guard does
not force an optional-route detour. Forest room additions use the descent
platforms, the bed, the nest entrance and the broad crown rest. Boss entry/exit
floors and recovery routes stay clear.

Flyers sit 13–20 units above their supporting floor and remain lash reachable.
Shooters use supported floor with a grounded approach. The river bridge supply
and repair guards retain their original placements; the extra bridge-region
guards occupy the preceding descent and a landing after the repaired crossing.

### Forest

| Enemy | Feet | Role |
| --- | --- | --- |
| EdgeRunGuard | `1000, 430` | Guard |
| EdgeStumpGuard | `1350, 430` | Guard |
| ClearingRearShooter | `2670, 430` | Shooter |
| BranchGuard | `2970, 410` | Guard |
| BranchScout | `3900, 410` | Flyer |
| RidgeApproachGuard | `4890, 430` | Guard |
| RidgeDropShooter | `6000, 330` | Shooter |
| RidgeExitGuard | `6400, 390` | Guard |
| HollowEntryGuard | `7090, 430` | Guard |
| HollowWestGuard | `7600, 430` | Guard |
| StoneEntryScout | `9070, 410` | Flyer |
| StoneMiddleGuard | `9641, 430` | Guard |
| StoneExitGuard | `10310, 450` | Guard |
| BanyanCrownScout | `11730, 210` | Flyer |
| BanyanDescentGuard | `12470, 310` | Guard |
| UpperLandingShooter | `14910, 390` | Shooter |
| ShrineBranchScout | `16955, 290` | Flyer |
| FinalHighGuard | `19460, 410` | Guard |
| RootFirstGuard | `855, -1900` | Guard, RootChamber |
| RootSecondScout | `1200, -1770` | Flyer, RootChamber |
| RootBedGuard | `2020, -1450` | Guard, RootChamber |
| NestEntryGuard | `490, -3600` | Guard, CanopyNest |
| CrownEastShooter | `1580, -4560` | Shooter, CanopyNest |

### River

| Enemy | Feet | Role |
| --- | --- | --- |
| BankGuard | `480, 430` | Guard |
| DockShooter | `1160, 390` | Shooter |
| BrokenDockGuard | `1435, 390` | Guard |
| BrokenDockScout | `1810, 410` | Flyer |
| FerryRearGuard | `2780, 430` | Guard |
| StoneBankGuard | `3040, 430` | Guard |
| StoneHighScout | `3760, 337` | Flyer |
| StoneCourtShooter | `4380, 390` | Shooter |
| GhatWestScout | `5100, 410` | Flyer |
| GhatCourtGuard | `6070, 310` | Guard |
| GhatExitGuard | `6805, 350` | Guard |
| BridgeDescentGuard | `7135, 390` | Guard |
| BridgeFarGuard | `9395, 350` | Guard |
| ChannelMiddleGuard | `11935, 350` | Guard |
| ChannelExitShooter | `12350, 390` | Shooter |

### Palace

| Enemy | Feet | Role |
| --- | --- | --- |
| GateLintelShooter | `1405, 270` | Shooter |
| GateDescentGuard | `2150, 365` | Guard |
| CourtyardRearGuard | `2820, 430` | Guard |
| WestColumnGuard | `3755, 390` | Guard |
| GalleryRearShooter | `5060, 430` | Shooter |
| RoofStairGuard | `5995, 270` | Guard |
| BrokenRoofGuard | `6820, 250` | Guard |
| BrokenRoofScout | `7585, 317` | Flyer |
| RoofCourtRearGuard | `8750, 430` | Guard |
| InnerWestScout | `9455, 370` | Flyer |
| InnerEastGuard | `10025, 390` | Guard |
| ThroneRoofGuard | `12880, 320` | Guard |

## Validation

`enemy_pacing_check.gd` probes all 70 enemies added since the original baseline.
It runs actual patrol physics, checks support across each patrol, safe arrivals
and diya envelopes, authored spawn markers, and grounded zero-ammunition lash
damage. It also rejects main-route placements on optional alternate-route
floors. Existing level checks retain real traversal, recovery, bridge repair,
shooter cover, checkpoints and forest room isolation.

The forest finish regression reloads terrain mode after toggling enemies; the
toggle applies during scene loading. This keeps finish/restart probes independent
of the new final encounters. Robin's isolated companion probes now hide all
uncontrolled enemy bodies from combat queries, retaining ClearingGuard for the
explicit combat checks. This removes assumptions about quiet authored locations
without changing Robin's behavior or weakening those checks.

Validation uses the existing Godot `4.7.2.stable.official.ed1daf0bf` executable at
`/home/sdixit/Downloads/Godot_v4.7.2-stable_linux.x86_64`, set as `GODOT_BIN`.
The final doubling pass on current main passed **36/36 suites**, smoke
import/export and the exported-pack headless launch. The resource check passed
all **19 packed scenes** from outside the project. `git diff --check` passed.

Graphical encounter captures provide visual QA, not a complete manual campaign
playthrough. Cumulative damage, combat fatigue and the added fights before each
diya still need a sustained player run. Generated `.godot/` and `builds/` output
is ignored and excluded from the change.

Rendered examples from the doubling pass are [forest clearing](screenshots/enemy-pacing/forest-clearing.png),
[river stone court](screenshots/enemy-pacing/river-stone-court.png), and
[palace roof](screenshots/enemy-pacing/palace-roof.png).
