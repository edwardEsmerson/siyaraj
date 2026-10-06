# Today's workflow

## Agreed rules

- Dash moves horizontally in Siya's facing direction.
- Dash preserves vertical momentum, with normal rise/fall gravity throughout.
- Dash starts on the ground or in the air. One air dash, restored on landing;
  ground dashes keep the air charge and use a short cooldown instead.
- Dash stops at solid walls. It grants i-frames for its duration plus a short
  grace: `take_damage` is ignored and enemy shots pass through. Damage sources
  may query `is_invulnerable()`. Boss hazards (Khara, Dhoomketu and Ravan) route through
  `take_damage`, so they respect the i-frames too.
- Dash cancels any sparkler phase; an attack pressed mid-dash swings when it ends.
- Dash preserves chakri charge progress. Charging pauses during the dash and
  resumes afterward; releasing K during the dash fires chakri when it ends.
- Tapping and holding jump produce the same fixed jump height.
- Jumping supports coyote time and jump buffering.
- One sparkler swing damages each enemy at most once.
- Taking damage briefly protects Siya from further hits.
- Movement programmer A owns player velocity and movement state.

Running, fixed-height jumps, coyote time and jump buffering are implemented.
Rocket dash, camera look-ahead and automatic fall recovery are implemented.
Player combat and the guard encounter are implemented.

## Ownership

Assign team members to these roles at the kickoff. Names remain unassigned;
the proposal lists members but does not specify their technical roles.

| Role | Owned files and work | First deliverable |
| --- | --- | --- |
| A, movement | `scripts/player/`, `resources/player/`, `scenes/player/` | Run and fixed-height jump |
| B, combat | `scripts/combat/`, `scripts/enemies/`, `scenes/enemies/`, `scenes/combat/` | Standalone melee and enemy encounter |
| C, levels | `scenes/levels/` | Movement playground with measured gaps |
| D, art | `assets/` | Readable placeholders and temporary effects |
| E, integration/testing | `scenes/main/`, `scripts/main/`, project settings, exports | Launch, restart, integration, test notes |

Only E edits the main scene. Coordinate before editing another owner's files.
B coordinates with A before attaching combat to the player. Scene instances
provide the handoff; avoid replacing another owner's scene with a local copy.

## Inputs and collision conventions

| Action | Keyboard |
| --- | --- |
| `move_left` | A, Left arrow |
| `move_right` | D, Right arrow |
| `jump` | Space |
| `dash` | Shift |
| `attack` | J |
| `restart` | R |

Use input actions rather than hardcoded keys. Coordinates are in pixels;
positive Y points down. Player and enemy roots sit at their feet.
The current player collider is 24 x 40; enemy collider is 32 x 40.

| Physics layer number | Bit value | Purpose |
| --- | --- | --- |
| 1 | 1 | Solid world |
| 2 | 2 | Player body |
| 3 | 4 | Enemy body |
| 4 | 8 | Player attack |
| 5 | 16 | Enemy attack |

The shared melee component queries enemy bodies for player attacks and the
player body for enemy attacks during each active physics tick. Bodies currently collide only with the world.
Contact damage and body blocking are not part of this setup.

## Controller and combat handoff

Movement states, knockback/death hooks, attack components and damage APIs below
are implemented:

- `player.gd` owns NORMAL, DASH, HURT, and DEAD states.
- A handles movement and jump/dash timing using the movement resource.
- B creates an attack component that accepts a facing direction when triggered.
- The player routes the `attack` input to that component.
- Damage targets expose `take_damage(amount: int, knockback: Vector2)`.
- `apply_knockback(impulse, duration)` interrupts dash and controls hurt recovery.
- `die()` emits `died`; main reloads the course.
- Player `take_damage` implements health, 0.8 s protection and lethal death.
- B implements enemy damage and prevents multiple hits per swing.
- Combat never writes player velocity directly.
- `AttackOrigin` is the placeholder marker for positioning the melee hit area.

`resources/player/default_movement.tres` is the shared tuning resource. Its
defaults live in `scripts/player/movement_settings.gd`; Inspector overrides
are saved in the resource. Initial values are hypotheses, not final balance.

## Next ready tasks

| Owner | Task | Dependency | Pass condition |
| --- | --- | --- | --- |
| A | Running and grounded collision | Setup | Accelerate, stop, reverse without corner sticking |
| A | Fixed jump, coyote time, buffer | Running | Tap/hold match; edge and landing jumps work |
| C | Movement playground | Setup | Flat floor, steps, gaps, ceiling and safe spawn |
| B | Enemy patrol and damage in isolated scene | Setup | Enemy reverses, takes a hit and dies |
| B | Single sparkler swing | Attack contract with A | Visible active window; one hit per target per swing |
| D | Player/enemy/effect placeholders | Current collider sizes | States readable at gameplay size |
| E | Camera follow and fall/restart loop | Working movement | Landings visible; falling always recoverable |
| A | Rocket dash | Jumping | Cross gap, stop at walls, restore air dash on landing |

Use Ready, Doing, Review, Done. Each card has one owner and a playtestable
pass condition. Review movement together before integrating combat.

## Setup acceptance

- F5 opens the movement playground, Siya, enemy placeholder and control reminder.
- Gameplay keys report their named input action on screen.
- R reloads the scene and resets the input reminder.
- All scenes open independently without missing resources.
- The smoke PCK launches outside the editor.
- Standalone export requires matching export templates; record that blocker now.

Full level art, combos, extra moves, Robin, boss, audio and story remain later
milestones. Stop adding features during today's final hour.

## Hours 0.5 to 2 handoff

- A's run/jump controller is implemented in `scripts/player/player.gd`.
- C's playground has a run lane, 40 px steps, 70/120 px gaps, a low ceiling,
  a ledge for coyote/buffer testing and a lower safety floor.
- B's patrol/damage foundation is implemented in `scripts/enemies/enemy.gd`.
  (The original `enemy_test.tscn` is replaced by `scenes/dev/sandbox.tscn`.) Main-course
  enemy behaviour and player combat are deliberately not connected yet.
- D's grey placeholders remain readable; Siya's eye indicates facing direction.
- E added horizontal camera follow to make the extended course playable.
  Camera feel, fall boundaries and automatic restart remain in the next block.
- `tests/movement_check.gd` checks actual physics, jump timing and enemy damage.

Next: rocket dash, camera tuning, automatic fall recovery, then the team movement
playtest before integrating the sparkler attack.


## Hours 2 to 3.25 handoff

- Shift starts a horizontal rocket dash in the current facing direction.
- Dash speed is 720 px/s for 0.15 s, covering 108 px. Tune both values in
  `resources/player/default_movement.tres` through the Inspector.
- Dash suspends gravity, locks its direction, consumes one air charge, and
  restores the charge on landing. Holding Shift does not automatically dash again.
- Solid walls end the dash immediately. Normal dash completion returns to running
  speed; releasing movement then uses the existing deceleration.
- Siya turns gold with an orange exhaust during dash and dims when its charge
  is spent. The HUD also shows whether dash is ready.
- The camera eases toward 140 px of facing-direction look-ahead. Vertical framing
  stays fixed so platforms do not move during a jump. Limits cover the full course.
- The lower safety floor is removed. Falling below Y=580 or pressing R reloads
  the course, resetting the player, enemy, camera and input reminder.
- After the existing run/jump stations, a 220 px gap tests comfortable jump/dash
  traversal. A 250 px gap tests a jump very close to the edge with a dash near
  the apex. An 8 px wall tests high-speed collision at the end.
- Combat still comes next. (At this step dash granted no damage protection; ground
  dash with i-frames later replaced that rule, see Agreed rules.)

Validation commands, with the Godot executable on PATH or its full path substituted:

```bash
godot --headless --path . --script tests/movement_check.gd
godot --headless --path . --script tests/dash_check.gd
GODOT_BIN=godot tools/smoke_build.sh
GODOT_BIN=godot tools/run_smoke_build.sh --headless --quit-after 120
```

The dash checks cover distance and direction, mid-dash opposite input, air-charge
limits, gravity recovery, landing recharge, thin walls, low ceilings, both gaps,
knockback interruption, automatic fall recovery and manual restart.

Next team checkpoint: play the entire course and tune movement together before
integrating sparkler combat. Automated checks verify behaviour; they do not decide
whether the controller feels enjoyable.

## Hours 3.75 to 5.25 handoff

- Step 4 decision: jump height is fixed. Space release no longer cuts upward
  velocity, including buffered jumps. Coyote time and buffering remain intact.
- `scripts/combat/melee_attack.gd` is shared by Siya and the guard. A swing locks
  its facing direction, queries bodies only while active, and records each
  target to prevent repeated damage during one swing.
- Siya's sparkler uses 0.08 s wind-up, 0.10 s active and 0.36 s recovery.
  Run and jump remain available; dash, hurt and death cancel the swing.
- Both combatants have three health. Damage goes through `take_damage`;
  player movement still owns knockback. Siya gets 0.8 s damage protection,
  including while dashing. (Dash i-frames were added later; see Agreed rules.)
- Guard states are patrol, chase, attack, hurt and dead. Its strike has
  0.45 s wind-up, 0.12 s active and 0.65 s recovery. Orange signals wind-up;
  a red forward hitbox signals the active attack. Hits interrupt its swing.
- Guards stop at unsupported platform edges. Bodies do not block one another;
  only timed attack hitboxes deal damage.
- Main course station 6 now includes a working guard. The separate
  combat arena offered immediate combat testing (now `scenes/dev/sandbox.tscn`).
- HUD shows Siya's health and guard defeat. Lethal damage, falling and R reload
  the scene, restoring both characters. The existing camera tuning is preserved.
- Run `tests/combat_check.gd` alongside the movement and dash checks.

The earlier handoff sections record previous milestones. The fixed jump and
combat behaviour described here replace their variable-jump and placeholder
notes. Next: team combat playtest, then tune feedback and difficulty before
starting production art or additional attacks.

The buffer/coyote course obstacle is removed because its 80 px ledge exceeds
the current 45 px jump. A flat floor now connects the ceiling section to combat.
Coyote time and jump buffering remain in the controller. Combat is station 5.


## Hours 5.25 to 6.25 handoff

- F5 opens the combined prototype course. It teaches running, the agreed fixed-height
  jump, short gaps, low ceilings, air dash, sparkler combat and a final jump to a flag.
- The 220 and 250 px dash gaps come before the guard. The existing movement tuning
  and combat timings are preserved. No hit pause is added.
- The arena has safe floor around the guard. Defeating it opens a solid exit gate.
  The finish rejects completion while the guard is alive.
- Reaching the flag displays elapsed time and a replay prompt. Time freezes while
  movement stays available. R immediately resets the entire course.
- The compact HUD shows controls, health, dash availability, contextual hints and
  elapsed time. World hints leave landing platforms visible.
- Dash leaves fading world-space afterimages and a launch burst. Sparkler attacks
  show an animated arc; confirmed damage produces sparks and a hit word.
- Guards show orange wind-up, red strike and dim recovery with matching labels.
  Damage briefly flashes the guard; defeat produces a BOOM burst.
- Siya flashes on damage and blinks during her existing protection. Death shows
  a DOWN burst and a 0.35 s restart cue in the combined course.
- Open `scenes/main/movement_playground.tscn` with F6 for the original tuning
  course. Existing movement and dash checks target that scene. The dev
  sandbox (`scenes/dev/sandbox.tscn`) replaces the isolated combat arena.
- `tests/course_check.gd` checks new gap traversal, trail expiry, gate collision,
  real sparkler combat, exit unlock, final jump, completion, replay and death recovery.
- The export preset explicitly includes the burst script and movement playground.

Run all four checks, then export and run the pack outside the editor:

```bash
godot --headless --path . --script tests/movement_check.gd
godot --headless --path . --script tests/dash_check.gd
godot --headless --path . --script tests/combat_check.gd
godot --headless --path . --script tests/course_check.gd
GODOT_BIN=godot tools/smoke_build.sh
GODOT_BIN=godot tools/run_smoke_build.sh --headless --quit-after 120
```

Next is the fresh-player test. Record first-play duration, misunderstood controls,
missed jumps and unreadable attacks. Automated traversal checks do not establish
movement feel or a two-minute first-play completion time.

## Flying enemy handoff

- Combat owns the reusable flying enemy and projectile scenes/controllers and
  an isolated arena (now the dev sandbox Flyer encounter). Level integration
  places a flyer before the guard in the combined prototype course; no player
  controller or main-scene changes are required. The guard still opens the exit.
- The flyer has three health and uses the existing `take_damage` API plus
  `health_changed` and `died` signals. It patrols at 60 px/s within 90 px of spawn,
  reverses at walls, and keeps its spawn altitude even after knockback.
- Detection requires a living player within 300 px and a clear world-only ray.
  A 0.45 s orange charge locks the shot direction toward the player's body center.
  Patrol continues during charging and the 1.2 s reload. Damage, lost visibility,
  or leaving range cancels a charge. Shots travel straight without homing.
- Projectiles are enemy attacks on layer 5 (bit 16), sweeping against world and
  player bodies (mask 3). Each shot moves at 220 px/s, deals one damage through
  the player controller, and disappears on its first impact or after 3 s.
  Player protection consumes a shot without further damage. Existing shots
  survive their shooter and are cleared when the scene restarts.
- Jump + J reaches the flyer at its default placement. Contact damage remains
  absent. Tune patrol, detection, charge/reload, and projectile values on the
  flying enemy root in the Inspector.
- Run `tests/flying_enemy_check.gd` alongside the four existing checks. It covers
  flight bounds/altitude/walls, moving charge/reload, locked aim and dodging,
  interruption, swept collisions, protection, projectile expiry, jumping melee,
  death/restart, and the guard-controlled gate. The smoke export includes the
  flying arena and projectile dependencies.

Manual checkpoint: play the sandbox Flyer encounter with F6, then the whole course with F5.
Check that the orange charge and shot are readable, jumping hits feel reachable,
and the flyer/guard encounter is fair with the existing three-health player.

## Brute enemy handoff

- Combat owns `scenes/enemies/brute.tscn` and the isolated
  arena (now the dev sandbox Brute encounter). The Brute reuses
  the guard controller and shared melee component as an ordinary enemy.
- The collider is 48 x 64, compared with the guard's 32 x 40. Its broad shoulders,
  brown body, dark bracers and belt distinguish it at gameplay size.
- Six health, two damage per swing, 300/-180 knockback and a wider 64 x 48 hitbox
  make it stronger than a guard. Patrol/chase speeds are 40/70 px/s. Wind-up is
  0.7 s, active time 0.16 s and recovery 0.95 s. Facing locks for each swing.
- Hits interrupt its attack; incoming knockback is multiplied by 0.55. A 32 px
  ground probe keeps the wider body away from unsupported edges. Existing guard
  defaults and the player movement/damage APIs are preserved.
- Level integration places it at (4020, 430), after the regular guard. It has
  ordinary floating health/status feedback, with no boss phases or boss UI.
  The regular guard still owns the exit gate. The isolated arena shares main
  restart/HUD handling; integration now derives its defeat label from enemy name.
- `tests/brute_check.gd` covers size and strength, bounded patrol, edges and walls,
  chase, wind-up/dodging/recovery, hit reach and facing, one hit per swing without
  damage protection, interruptions, knockback resistance, six real sparkler hits,
  defeat/restart and course gate ownership. Course regression isolates the Brute
  while checking the existing guard encounter and verifies replay restores it.
- Run the new check alongside all five existing checks. The smoke export includes
  the Brute arena and its dependencies.

Manual checkpoint: play the sandbox Brute encounter with F6, then the whole course with F5.
Check that its heavy swing is readable and the long recovery offers a fair
counterattack window with Siya's existing three health.
## Ground shooter handoff

- Combat owns `ground_shooter.gd`, its reusable enemy scene, the homing projectile
  script/scene and an isolated arena (now the dev sandbox Shooter encounter). Level integration
  places a shooter after the guard at (3970, 430) without changing player movement
  or the main scene. The guard still controls the exit gate.
- The shooter has three health, patrols at 45 px/s within 70 px of spawn, uses
  gravity and reverses at walls and unsupported edges. It stops during a 0.65 s
  purple charge and patrols during its 1.6 s reload. Detection requires a living
  player within 260 px and a clear world-only ray. Hits, loss of sight, leaving
  range or losing ground contact cancel a pending charge.
- Purple comet-shaped bolts track the player's body center at 170 px/s with a
  maximum turn rate of 2.4 radians/s. They use the straight projectile's shared
  swept collision/damage handling, deal one damage, and expire after 2.8 s.
  Missing or dead targets leave them flying along their last heading. Shots
  survive their shooter's defeat and are cleared on restart. Flyer shots remain
  straight and orange. There is no contact damage. (Dash i-frames, added later, let a dash pass
  through bolts; see Agreed rules.)
- `tests/ground_shooter_check.gd` covers gravity, patrol bounds, walls/ledges,
  charge/reload, interruption, bounded homing and moving/deleted/dead targets,
  swept impacts, protection, melee, death/restart and the guard-controlled gate.
  The export preset includes the isolated arena and homing dependencies.

Manual checkpoint: play the sandbox Shooter encounter with F6, then the course with
F5. Check that the purple charge and steering are readable, jumping/dashing past
bolts is fair, and the three-enemy encounter works with Siya's three health.

## Three-weapon playground handoff

The forest also uses this controller through `scenes/player/forest_player.tscn`.
Forest doors preserve health, ammunition and weapon cooldowns across the
same-level room transitions. Death and R restore a fresh loadout. The
forest HUD displays weapon state; the original prototype still uses its
original player scene. `forest_weapons_check.gd` validates this integration.

- Open `scenes/dev/weapons_playground.tscn` with F6. All three weapons are
  unlocked in the isolated playground. Shared player and main-course scripts
  retain their current behaviour.
- Sparkler: J for a single ground or aerial lash. Jumping preserves the swing;
  recovery presses are ignored. Dash, hurt and death cancel it.
- Skyshot replaces anar: L fires one projectile in the facing direction,
  including in the air. Five shots per round, with a 0.45-second firing recovery.
  Misses and wall impacts cost ammo. There are no pickups or timed refills.
- Fresh player instances on level entry/death start with five shots; nonlethal
  damage, enemy respawns and moving between stations never refill ammo. R is the
  playground's full new-round reset. Production level transitions still need
  integration with the eventual three level scenes.
- Recoil is controlled by `weapons_playground_player.gd`: 120 px/s for 0.12 s,
  opposite the fired direction. It sweeps against world collisions, permits jump
  input and grants neither hurt state nor damage protection.
- `skyshot_projectile.gd` sweeps against walls and enemies, deals two damage to
  the first collision and expires after 1.2 seconds. The export preset explicitly
  includes runtime-loaded weapon scripts.
- Chakri: hold/release K. Full charge is one second; release starts a 30-second
  cooldown. Interrupted charges cost nothing. Its cooldown is independent of ammo.
- The 4200 px map has sparkler, skyshot and chakri practice areas, a safe movement
  lane and a separate guard encounter. The old shield/ruler station is replaced
  by a firing line and distant four-health targets. The crowd retains three health
  for a one-spin clear. The HUD shows ammo and chakri cooldown.
- `tests/weapons_check.gd` verifies single-lash timing, projectiles, wall collision,
  five-shot limits, recoil, empty input, refill lifecycle and chakri cooldown.
  `tests/weapons_map_check.gd` verifies ranged targets, recoil space, crowd clear,
  respawn, traversal, ammo persistence and camera boundaries.

## Test area cleanup

- The per-enemy arenas (combat, Brute, flyer, ground shooter), their course
  scenes and arena scripts, and the button-driven `enemy_test.tscn` are removed.
  All enemies now live in the forest.
- `scenes/dev/sandbox.tscn` replaces them: a flat walled arena with one enemy.
  Choose `encounter` (none, Guard, Brute, Flyer, Shooter) and `three_weapons`
  on the root, then press F6. Bosses get their own arenas under `scenes/bosses/`.
  Enemy checks select an encounter through `Sandbox.next_encounter`.
- The weapons playground and its dummies moved to `scenes/dev/` and
  `scripts/dev/`. The movement playground remains for the movement and dash checks.

## Boss 1 (Khara) handoff

- Combat owns `scenes/bosses/khara.tscn` and `scripts/bosses/` (the Khara
  controller, ladi and shockwave hazards, and the arena script). The isolated
  `scenes/bosses/khara_arena.tscn` uses the forest player with all three weapons.
  There are no player, main-scene or forest changes. The full moveset is in
  `docs/bosses/boss1-khara.md`.
- Khara has 24 health, poise (no knockback or interruption) and no contact damage.
  - Gada slam: 0.85 s orange wind-up with a ground zone, 2 damage, then a 1.1 s
    recovery. It releases a low shockwave that Siya can jump.
  - Ladi: 1.2 s fuse, then pops travel along the ground toward Siya's side.
    Yellow chevrons show the direction.
  - Phase 2 starts at 12 health: faster, double shockwave, a second ladi from the far
    wall, and a slam followed by a ladi.
- `scenes/ui/boss_health_bar.tscn` is the generic bar shared by every boss. Call
  `bind(boss)` on any node with `max_health`, `health` and `health_changed`. It
  also uses `died`, `phase_changed`, `boss_name` and `boss_title` when they exist;
  set `phase_thresholds` (fractions of max health) for the phase tick marks.
- Hazards join the `boss_hazards` group. Ladis also join `boss_ladis`. Defeat frees them all.
- `tests/khara_boss_check.gd` covers ladi direction, fuse safety, sequential pops,
  wall clipping, jumping a ladi, slam tell, damage, reach and recovery, shockwaves,
  the 50% phase change, the phase 2 pincer, AI choices, real weapon damage, the health
  bar, defeat and restart.

Manual checkpoint: play the Khara arena with F6. Check that the orange and yellow tells
read clearly at gameplay speed, and that the phase 2 pincer is fair with three health.

## Boss 2 (Ravan) handoff

- Combat owns `scenes/bosses/ravan/` and `scripts/bosses/ravan/`. The isolated
  `scenes/bosses/ravan/ravan_arena.tscn` uses the forest player with all three
  weapons and 5 health. The full moveset is in `docs/bosses/boss2-ravan.md`.
- Ten heads take turns attacking; only an active head can be hurt. Knocking out
  enough heads at once exposes the navel core, the only place Ravan takes damage.
  Phase changes (20 and 10 core health) start Dashanan Fury pillar waves.
- Ravan follows the generic boss contract: `max_health`/`health` alias his core
  health, and he emits `health_changed`, `phase_changed` and `died`. His
  `BossUI/HealthBar` is an instance of `scenes/ui/boss_health_bar.tscn`;
  `BossUI/HeadIndicators` (`ravan_head_indicators.gd`) is a small Ravan-only add-on
  showing one pip per head, the phase, the knockout goal and the exposure cue.
- Hazards (pillars, beams, lightning, shockwaves) and the shared enemy projectiles
  all damage Siya through `take_damage`, so dash i-frames apply.
- `tests/ravan_check.gd` covers head slots, guard, knockout and regrowth, navel
  exposure, real weapons, head attacks, phases, Fury safe lanes, dash i-frames,
  the generic boss bar, defeat and restart.

Manual checkpoint: play the Ravan arena with F6. Check that the head pips read
clearly above the boss bar and that Fury lanes are fair without dashing.
