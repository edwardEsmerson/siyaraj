# Boss 2: Ravan (Dashanan)

Play the isolated arena with F6: `scenes/bosses/ravan/ravan_arena.tscn`. The
campaign reaches it through `scenes/main/palace_showdown.tscn`.
Regression check: `godot --headless --path . --script res://tests/ravan_check.gd`.
Ravan is being renamed Swaminathan (TODO B1); file and class names still say `ravan`.

## Concept

Ravan, king of Lanka, is the final major boss. He is known as Dashanan, the
ten-headed one. Each of the ten heads attacks, and Siya cuts them down one by
one until none is left.

Ravan is stationary and stands at the centre of a 960 x 540 arena. Siya
passes through his body. The project has no contact damage, so only his
attacks hurt her.

## Rules

1. **One health pool, hit anywhere.** Ravan has 80 health. The lash, skyshot
   and chakri hurt him anywhere on his body or his row of heads. There is no
   guarded state during normal fighting and no weak point to wait for.
2. **Every tenth severs a head, right to left.** Each 8 health lost severs his
   rightmost living head, so with *n* heads left the leftmost *n* remain. One
   hit takes at most one head (damage stops at the next threshold), so every
   head gets its own beat.
3. **No regrowth.** A severed head stays gone, and lost health never returns.
4. **Only living heads attack.** Heads are fixed attack origins on the body
   sprite. They do not move and cannot be targeted on their own.
5. **Defeat at zero heads.** The final hit severs the last head.

### The head-loss beat

When a head is severed, the body swaps to the next state sprite and shakes. A
white pop and an expanding ring mark where the head was, with a `SEVERED!`
burst and a banner such as `CHITTA SEVERED - 9 HEADS LEFT`. Ravan then
staggers for 0.6 s: pending telegraphs are cancelled and no head starts an
attack, but he can still be hit. If the lost head crosses a phase boundary,
the phase roar plays instead of the stagger.

### Head attacks

A head activates, **telegraphs**, **attacks** and then **recovers** before it
can be picked again. Because heads cannot move, the telegraph is drawn on the
head itself: a halo in the attack colour that grows and brightens, a charge
ring that fills, and the attack name above it. A white flash marks the moment
the attack leaves the mouth. If the head is severed during its telegraph, the
attack never fires.

## Head roster

The heads are the ten vices and faculties often given for Dashanan, numbered
left to right. Attacks come in five mirrored pairs. Heads fall right to left,
so the five leftmost heads cover every attack type, and the last three heads
standing (phase 3) carry the attacks that escalate in phase 3.

| # | Head | Meaning | Attack | Colour | Counterplay |
| --- | --- | --- | --- | --- | --- |
| 0 | Mada | Pride | Lightning | Cyan | Step off the marker |
| 1 | Krodha | Anger | Spread shot | Rose | Stand in the gaps between the shots, or jump |
| 2 | Lobha | Greed | Homing orb | Purple | Jump past it or dash through it; its turning is limited |
| 3 | Moha | Delusion | Fire breath | Orange | Leave the outlined beam before it ignites |
| 4 | Matsarya | Envy | Roar shockwave | Gold | Jump the low wave, or stand on a side ledge, which blocks it |
| 5 | Ahamkara | Ego | Roar shockwave | Gold | As for Matsarya |
| 6 | Manas | Mind | Fire breath | Orange | As for Moha |
| 7 | Kama | Desire | Homing orb | Purple | As for Lobha |
| 8 | Buddhi | Intellect | Spread shot | Rose | As for Krodha |
| 9 | Chitta | Will | Lightning | Cyan | As for Mada |

Attack details. All of them deal 1 damage, and Siya's 0.8 s damage protection
applies. Every attack leaves from the head's mouth, 10 px below its face centre.

- **Fire breath** draws a 330 x 34 px beam from the mouth toward Siya. Its aim
  locks when the beam appears. It shows an outline for 0.45 s, then burns for
  0.45 s.
- **Homing orb** reuses `homing_projectile.tscn`: 160 px/s, 2.2 rad/s turning,
  3.2 s lifetime. Phase 3 fires two orbs, 0.35 rad apart.
- **Roar shockwave** sends two waves along the floor from below the head, one
  in each direction. Each wave is 26 x 22 px and travels at 280 px/s. Walls and
  ledge faces stop it.
- **Lightning** marks a 44 px column at Siya's x position for 0.7 s, then
  strikes for 0.18 s. Phase 3 adds a second strike on the same spot at 1.15 s,
  so move and do not step back.
- **Spread shot** reuses `enemy_projectile.tscn`, tinted rose: 210 px/s with
  0.22 rad between shots. It fires 3 shots, or 5 in phase 3.

## Phases

| Phase | Heads left | Health | Heads at once | Gap | Telegraph | Attack | Recover |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 10 to 8 | 80 to 57 | 1 | 1.1 s | 0.9 s | 0.5 s | 1.2 s |
| 2 | 7 to 4 | 56 to 25 | 2 | 0.8 s | 0.8 s | 0.5 s | 1.0 s |
| 3 | 3 to 1 | 24 to 1 | 2 | 0.55 s | 0.7 s | 0.5 s | 0.9 s |

"Gap" is the minimum time between two heads starting. The same head never
attacks twice in a row while another living head can. When only one head is
left, it attacks alone.

Losing the head that leaves 7 or 3 heads starts the next phase. Ravan roars
for 1.2 s with the banner `PHASE N - DASHANAN AWAKENS`, then performs Dashanan
Fury. Phase 3 repeats Fury every 30 s of normal fighting. Ravan is guarded
(hits show `GUARDED`) during the intro, the roar and Fury. All values are in
the `PHASES` and `PHASE_HEADS` tables and the exports in
`scripts/bosses/ravan/ravan_boss.gd`.

## Super move: Dashanan Fury

Only the living heads take part. Ten floor lanes, each 88 px wide, span the
arena from x=40 to x=920, shared out evenly among the living heads (with ten
heads each owns one lane; with five, each owns two).

| Time | Event |
| --- | --- |
| 0.0 to 1.4 s | Dark red screen tint, `DASHANAN FURY` banner. Living heads ignite one by one, left to right, every 0.12 s. Thin lines show the lanes each head will burn |
| 1.4 s | Wave 1 telegraph (1.6 s). Eight lanes show a bright red floor stripe and a faint pillar outline. The two safe lanes glow teal with a `SAFE` label. A head whose lanes are all safe goes dark |
| 3.0 s | Fire pillars cover the full height of the red lanes for 0.4 s, then a 0.3 s pause |
| Each later wave | The safe gap moves. Telegraph is 1.0 s in phase 2 and 0.85 s in phase 3, then 0.4 s of fire and a 0.3 s pause |
| End | 0.6 s outro. The tint fades and Ravan is **spent**: for 2.5 s no head attacks (`SPENT - STRIKE!`), a free punish window |

A Fury runs **one wave per living head**, up to the phase's full sequence, so
it shortens as he weakens:

- Phase 2 (starts with 7 heads, 5 waves): [4,5] → [1,2] → [4,5] → [7,8] → [5,6]
- Phase 3 (3 heads or fewer, 3 waves at most): [4,5] → [7,8] → [4,5] → [1,2] →
  [3,4] → [6,7], cut to the first *n* waves

The first gap is under Ravan, so Siya reaches it from anywhere in the arena.
Each later gap moves at most three lanes, about 190 px from the middle of the
old gap to inside the new one. That takes about 0.8 s at the 240 px/s run
speed, within the 1.15 to 1.3 s available. `tests/ravan_check.gd` checks this
rule. Jumping does not avoid the pillars, because they cover the full height.

## Death sequence

The final hit severs the last head (with its pop) and removes every Ravan
projectile and hazard still in the arena, so no stray hit can follow the win.
The banner shows `RAVAN FALLS`. The headless body shakes and flashes white and
red for 0.9 s, then a large `DEFEATED` burst plays, the body dims and the
`died` signal fires. The arena then shows the victory prompt.

## Boss UI

Health uses the shared `scenes/ui/boss_health_bar.tscn` (instanced as
`BossUI/HealthBar`) with a tick at every tenth, one per head.
`BossUI/HeadIndicators` (`ravan_head_indicators.gd`) adds the Ravan-only row
above it: one pip per head, each over its own tenth of the bar, so the pips
go dark (a crossed ring) right to left as the bar drains. A pip lights in its
attack colour while that head attacks, and turns red or teal during Fury.
Below the pips: the phase and `HEADS n/10`, plus `SPENT - STRIKE!` after Fury.

## Integration notes

- Scenes: `scenes/bosses/ravan/ravan.tscn` (the boss, placed with its root on
  the floor) and `ravan_arena.tscn`.
- Scripts: `ravan_boss.gd` runs the fight and owns the ten head slots (plain
  data, not nodes), `ravan_body.gd` draws the body state and holds the head
  offsets, `ravan_hurtbox.gd` forwards hits to the one health pool,
  `ravan_hazard.gd` (telegraphed beam, column and pillar), `ravan_shockwave.gd`
  and `ravan_head_indicators.gd`.
- `Ravan/Hurtbox` is one StaticBody2D on the enemy body layer (bit 4) with two
  shapes: the body (120 x 130) and the head row (440 x 80). The existing lash,
  skyshot and chakri work unchanged and hit him once per swing.
- Signals: `health_changed`, `head_lost(index, remaining)`, `phase_changed`,
  `fury_started`, `fury_ended` and `died`. `max_health` and `health` meet the
  generic boss contract. `set_head_count(n)` jumps straight to *n* heads for
  tests, screenshots and dev snapshots.
- The arena overrides the player's `max_health` to 5 on the instance only. No
  player code changes.
- Ground dash i-frames apply to every Ravan hazard and projectile, which makes
  Fury and lightning easier to dodge. The safe-gap timing does not rely on it.

## Art handoff: body state sprites

Ravan is drawn as **one full-body sprite per head state**. Heads are severed
right to left, so state *n* shows the leftmost *n* heads. The same body, crown,
moustache and pose must hold across all states: generate state 10 first, get
it approved, then derive the others from it.

- **Files:** `assets/sprites/swaminathan-states/state_10.png` (ten heads) down
  to `state_01.png` (one head) and `state_00.png` (headless, used for the
  death beat). `ravan_body.gd` loads whichever exist and falls back to the
  code-drawn placeholder for the rest, so states can land one at a time.
- **Canvas:** 880 x 480 px, the same for every state, transparent background.
  Ravan's feet sit at the bottom centre of the canvas, which is the boss
  origin. It is placed at scale 0.5 (1 game unit = 2 art px), so in game it
  spans 440 x 240 units.
- **Head positions:** heads must sit where the code fires from. The single
  source is `HEAD_OFFSETS` in `scripts/bosses/ravan/ravan_body.gd`: the face
  centre of each head in game units from the feet, left to right. The
  placeholder arc is x = -198 to 198 (art px -396 to 396 from the centre) and
  y = -150 (outer heads) to -180 (centre heads), i.e. art px 300 to 360 above
  the bottom edge. Either draw the heads there, or, once state 10 is approved,
  measure its face centres and update `HEAD_OFFSETS` (art px / 2). The mouth,
  where attacks spawn, is 10 units below each face centre (`MOUTH_OFFSET`).
- **Lost heads:** show a neck stump or nothing where a head was; the code adds
  the pop and flash. Keep the remaining heads exactly in place between states.
- **Optional extras**, only if time allows: a hurt flash per state (code
  already flashes the sprite white), and fury or dying poses. The code tints
  the body red during Fury, grey while staggered or spent, and flashes and
  dims it on death.
- **Review:** `xvfb-run -a godot --path . --resolution 960x540 -s
  tools/ravan_shots.gd` renders `docs/screenshots/swaminathan_states.png` (all
  11 states), `swaminathan_fight.png` (telegraph glows and the head UI) and
  `swaminathan_sever.png` (the head-loss beat) with whatever art is present.

### Effects

Code currently draws all of these: the fire-breath beam, homing orb and spread
shot, roar shockwave, lightning marker and bolt, Fury pillar with its floor
stripe and teal safe-lane marker, the telegraph halo and charge ring, and the
head-loss pop. Optional: a Lanka palace backdrop (960 x 540) for the arena.
