# Today's workflow

## Agreed rules

- Dash moves horizontally in Siya's facing direction.
- Dash can only start while airborne. One air dash, restored on landing.
- Dash stops at solid walls and gives no invulnerability.
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
  Open `scenes/enemies/enemy_test.tscn` with F6 to test it separately. Main-course
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
- Combat still comes next; dash grants no damage protection.

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
  including while dashing. Dash itself grants no protection.
- Guard states are patrol, chase, attack, hurt and dead. Its strike has
  0.45 s wind-up, 0.12 s active and 0.65 s recovery. Orange signals wind-up;
  a red forward hitbox signals the active attack. Hits interrupt its swing.
- Guards stop at unsupported platform edges. Bodies do not block one another;
  only timed attack hitboxes deal damage.
- Main course station 6 now includes a working guard. The separate
  `scenes/combat/combat_arena.tscn` offers immediate combat testing with F6.
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
  course. Existing movement and dash checks target that scene. The isolated
  combat arena remains available with F6.
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


## Three-weapon playground handoff

- Open `scenes/combat/weapons_playground.tscn` with F6. All three weapons are
  unlocked in the isolated playground. Shared player and main-course scripts
  retain their current behaviour.
- Sparkler: J for a single ground or aerial lash. Jumping preserves the swing;
  recovery presses are ignored. Dash, hurt and death cancel it.
- Skyshot replaces anar: S/Down + J fires one projectile in the facing direction,
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
