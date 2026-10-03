# Today's workflow

## Agreed rules

- Dash moves horizontally in Siya's facing direction.
- One air dash, restored on landing.
- Dash stops at solid walls and gives no invulnerability.
- Holding jump produces a higher jump than tapping it.
- Jumping supports coyote time and jump buffering.
- One sparkler swing damages each enemy at most once.
- Taking damage briefly protects Siya from further hits.
- Movement programmer A owns player velocity and movement state.

Running, variable-height jumps, coyote time and jump buffering are implemented.
Dash and player combat remain agreed requirements for subsequent milestones.

## Ownership

Assign team members to these roles at the kickoff. Names remain unassigned;
the proposal lists members but does not specify their technical roles.

| Role | Owned files and work | First deliverable |
| --- | --- | --- |
| A, movement | `scripts/player/`, `resources/player/`, `scenes/player/` | Run and variable jump |
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

B adds attack Area2D nodes next. Player attacks detect enemy bodies; enemy
attacks detect the player body. Bodies currently collide only with the world.
Contact damage and body blocking are not part of this setup.

## Controller and combat handoff

The following is the agreed integration plan, not an implemented API yet:

- A adds NORMAL, DASH, HURT, and DEAD states in `player.gd`.
- A handles movement and jump/dash timing using the movement resource.
- B creates an attack component that accepts a facing direction when triggered.
- The player routes the `attack` input to that component.
- Damage targets expose `take_damage(amount: int, knockback: Vector2)`.
- A implements player knockback, protection timing, and death in that method.
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
| A | Variable jump, coyote time, buffer | Running | Tap/hold differ; edge and landing jumps work |
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
