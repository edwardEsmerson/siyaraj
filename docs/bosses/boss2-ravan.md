# Boss 2: Ravan (Dashanan)

Play the isolated arena with F6: `scenes/bosses/ravan/ravan_arena.tscn`.
It is not wired into level progression.
Regression check: `godot --headless --path . --script res://tests/ravan_check.gd`.

## Concept

Ravan, king of Lanka, is the final major boss. He is known as Dashanan, the
ten-headed one. In the Ramayana, his heads grow back each time Ram cuts one
off. Vibhishan then tells Ram that Ravan keeps the amrit, the nectar of
immortality, in his navel. Ram's arrow to the navel ends the fight.

The fight follows this story. Each of the ten heads attacks, and each can be
knocked out. A knocked-out head grows back unless Siya knocks out enough heads
fast enough. When that happens, Ravan staggers and his navel opens. That is the
only point where his health bar (the "core") takes damage.

Ravan is stationary and stands at the centre of a 960 x 540 arena. Siya
passes through his body. The project has no contact damage, so only his
attacks hurt her.

## Fight loop

1. **Heads activate.** An idle head is guarded: a hit shows `GUARDED` and does
   nothing. When a head activates, it lunges about 85 px down and outward on
   its neck. It glows in its attack colour and shows its attack name with a
   charge ring. This is the **telegraph**.
2. **Attack.** At the end of the telegraph, the head performs its attack. The
   attacks are listed under [Head roster](#head-roster).
3. **Dazed.** The head then droops, shows `DAZED` and stays low, giving a
   punish window. It is vulnerable during telegraph, attack and dazed.
4. **Knockout.** A head goes limp when its health runs out (2 HP: two lashes,
   one skyshot or one chakri). Knocking it out during the telegraph cancels
   its attack. Hits that leave it standing do not interrupt the attack.
5. **Regrowth.** A grey ring on a knocked-out head drains toward regrowth.
   When it empties, the head flashes white and returns with full health.
6. **Exposure.** When enough heads are knocked out at once, Ravan staggers.
   His navel opens and the amrit glows green. Only the navel can be damaged,
   and it is at standing sparkler and skyshot height. Knocked-out heads stay
   down while the navel is open.
7. **The heads grow back.** When the window closes, every knocked-out head
   regrows and the count resets.

The HUD bar shows core health with phase markers, plus one pip per head: lit
when active, a hollow ring when knocked out, teal when silent during Fury. The
line below it shows the number of knockouts and the number required.

## Head roster

The heads are the ten vices and faculties often given for Dashanan. They are
numbered from left to right. Attacks come in five mirrored pairs, so either
side of the arena gets every kind of threat.

| # | Head | Meaning | Attack | Colour | Counterplay |
| --- | --- | --- | --- | --- | --- |
| 0 | Mada | Pride | Roar shockwave | Gold | Jump the low wave, or stand on a side ledge, which blocks it |
| 1 | Krodha | Anger | Fire breath | Orange | Leave the outlined beam before it ignites |
| 2 | Lobha | Greed | Homing orb | Purple | Jump past it or dash through it; its turning is limited |
| 3 | Moha | Delusion | Lightning | Cyan | Step off the marker |
| 4 | Matsarya | Envy | Spread shot | Rose | Stand in the gaps between the shots, or jump |
| 5 | Ahamkara | Ego | Spread shot | Rose | As for Matsarya |
| 6 | Manas | Mind | Lightning | Cyan | As for Moha |
| 7 | Kama | Desire | Homing orb | Purple | As for Lobha |
| 8 | Buddhi | Intellect | Fire breath | Orange | As for Krodha |
| 9 | Chitta | Will | Roar shockwave | Gold | As for Mada |

Attack details. All of them deal 1 damage, and Siya's 0.8 s damage protection
applies.

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

Head layout (global coordinates in the arena; Ravan's root is at (480, 430)):
the homes form an arc from x=282 to x=678, at y=250 (centre heads) to y=280
(outer heads). The heads lunge to y=335 to 365. A jumping lash reaches every
lunging head, and a skyshot fired at the top of a jump hits the outer heads.

## Phases

The core has 30 health. Damage clamps at each phase boundary, so every phase
and its super move are played.

| Phase | Core HP | Heads at once | Gap | Telegraph | Dazed | Regrow | Knockouts to expose | Navel window |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 30 to 21 | 1 | 1.1 s | 0.9 s | 1.2 s | 12 s | 3 | 5.0 s |
| 2 | 20 to 11 | 2 | 0.8 s | 0.8 s | 1.0 s | 11 s | 4 | 4.5 s |
| 3 | 10 to 0 | 2 | 0.55 s | 0.7 s | 0.9 s | 10 s | 5 | 4.0 s |

The attack itself always lasts 0.5 s. The same head never activates twice in
a row.

Clearing each phase fully restores Siya's health, including the final defeat.
The health HUD updates immediately. Ordinary core hits and head knockouts do not heal her.

A phase change closes the navel and regrows all heads. Ravan roars for 1.2 s,
showing the banner `PHASE N - DASHANAN AWAKENS`, then performs Dashanan Fury.
Phase 3 repeats Fury every 30 s of normal fighting. All values are in the
`PHASES` table and the exports in `scripts/bosses/ravan/ravan_boss.gd`.

## Super move: Dashanan Fury

All ten heads, including knocked-out ones, return and become guarded. Each
head owns one of ten floor lanes, each 88 px wide, spanning the arena from
x=40 to x=920.

| Time | Event |
| --- | --- |
| 0.0 to 1.4 s | Dark red screen tint, `DASHANAN FURY` banner. Heads ignite one by one, left to right, every 0.12 s. Thin lines show each head's lane |
| 1.4 s | Wave 1 telegraph (1.6 s). Eight lanes show a bright red floor stripe and a faint pillar outline. The two safe lanes glow teal with a `SAFE` label, and their heads go dark with closed eyes |
| 3.0 s | Fire pillars cover the full height of the red lanes for 0.4 s, then a 0.3 s pause |
| Each later wave | The safe gap moves. Telegraph is 1.0 s in phase 2 and 0.85 s in phase 3, then 0.4 s of fire and a 0.3 s pause |
| End | 0.6 s outro. The tint fades and Ravan is spent: the navel opens for a 2.5 s bonus window |

Safe gaps, in lane order:

- Phase 2 (11.1 s): [4,5] → [1,2] → [4,5] → [7,8] → [5,6]
- Phase 3 (12.1 s): [4,5] → [7,8] → [4,5] → [1,2] → [3,4] → [6,7]

The first gap is under Ravan, so Siya reaches it from anywhere in the arena.
Each later gap moves at most three lanes, about 190 px from the middle of the
old gap to inside the new one. That takes about 0.8 s at the 240 px/s run
speed, within the 1.15 to 1.3 s available. `tests/ravan_check.gd` checks this
rule. Jumping does not avoid the pillars, because they cover the full height.
Reading the safe gap and running to it is the only answer.

## Death sequence

The final navel hit removes every Ravan projectile and hazard still in the
arena, so no stray hit can follow the win. The banner shows `RAVAN FALLS`.
The heads burst from the outside in, 0.18 s apart, followed by a large
`DEFEATED` burst after 0.8 s. The body dims and the `died` signal fires.
The arena then shows `Ravan defeated! R to replay.`

## Integration notes

- Scenes: `scenes/bosses/ravan/ravan.tscn` (the boss, placed with its root on
  the floor), `ravan_head.tscn` (one head) and `ravan_arena.tscn`.
- Scripts: `ravan_boss.gd` runs the fight, `ravan_head.gd`, `ravan_core.gd`
  (the navel hurtbox), `ravan_hazard.gd` (telegraphed beam, column and pillar),
  `ravan_shockwave.gd` and `ravan_head_indicators.gd`.
- Heads, the navel and the chest armour are StaticBody2D nodes on the enemy
  body layer (bit 4). The existing lash, skyshot and chakri therefore work
  without any changes to the player. The armour has no `take_damage`, so it
  absorbs skyshots that hit Ravan's chest.
- Signals: `health_changed`, `phase_changed`, `exposure_started`,
  `exposure_ended`, `fury_started`, `fury_ended` and `died`. `max_health` and
  `health` alias `max_core_health` and `core_health`, so Ravan meets the
  generic boss contract.
- The arena overrides the player's `max_health` to 5 on the instance only. No
  player code changes.
- Core health uses the shared `scenes/ui/boss_health_bar.tscn` (instanced as
  `BossUI/HealthBar`, with tick marks at both phase boundaries).
  `BossUI/HeadIndicators` (`ravan_head_indicators.gd`) adds the Ravan-only row
  above it: one pip per head, the phase, the knockout goal and `AMRIT EXPOSED`.
- Ground dash i-frames apply to every Ravan hazard and projectile, which makes
  Fury and lightning easier to dodge. The safe-gap timing does not rely on it.

## Art handoff: sprites and animations

The game uses nearest-neighbour filtering at gameplay scale. Every placeholder
is replaced by putting art in an `Art` slot:

- A `Sprite2D` with a texture hides the placeholder automatically.
- To animate, replace `Art` with an `AnimatedSprite2D` (also named `Art`). The
  code plays the animation names below whenever they exist in its
  SpriteFrames.

Each head is its own node (`Ravan/Heads/Head0` to `Head9`), so each can have
unique art.

### Heads: 10 variants, 48 x 48 px canvas each

Put the origin at the centre of the face. The mouth is about 10 px below
it, where projectiles spawn. The hurtbox is a 17 px radius circle.

| Animation | Frames | Notes |
| --- | --- | --- |
| `idle` | 2 to 4, loop | Slight sway or blink. Each head's expression shows its vice |
| `telegraph` | 3 to 4, loop | Mouth opening, eyes glowing. Code adds the colour halo, so keep it readable in all 5 attack colours |
| `attack` | 2 to 3 | Per-attack mouth pose: fire gape, roar, spit, lightning eyes |
| `exhausted` | 2, loop | Dazed and drooping (the punish window) |
| `knocked_out` | 1 to 2 | Limp, eyes as X or closed, darker. Code rotates the head about 0.6 rad outward |
| `regrow` | 4 to 6 | Sprouting or reforming, with a sparkle. Code scales from 0.3 to 1 over 0.6 s |
| `fury` | 2 to 3, loop | Eyes ablaze, maximum menace |
| `destroyed` | 4 to 6, one shot | Burst or stump for the death sequence |

The heads should share one crown and ear shape for consistency. Vary the face,
expression and jewel colour: Mada smug, Krodha furious, Lobha grasping, Moha
hazy-eyed, Matsarya sidelong, Ahamkara haughty and centred, Manas restless,
Kama alluring, Buddhi calm, Chitta stern.

### Body: 192 x 160 px canvas

Put the origin at the bottom centre, between the feet. Key points:

- Navel (amrit) at (0, -36). Keep this area clear, because code draws the glow.
- Shoulder line at y = -118.
- Neck anchors spread along the shoulders. The code draws the necks as 7 px
  lines from (home.x × 0.3, -118) to each head. Optional neck sprites can
  replace them later.

| Animation | Frames | Notes |
| --- | --- | --- |
| `intro` | 4 to 6 | Rising or arms spread |
| `idle` | 2 to 4, loop | Breathing; 20 arms optional |
| `exposed` | 2, loop | Staggered and slumped (code shifts the body 6 px down). Navel bare |
| `roar` | 3 to 4 | Phase transition |
| `fury` | 2 to 3, loop | Arms raised, glowing |
| `dying` | 6 to 8 | Collapse |
| `dead` | 1 | Fallen pose, which code dims |

### Effects

Code currently draws all of these.

- Fire-breath beam: a loopable 32 px-tall strip, plus start and end caps.
- Homing orb (purple) and spread shot (rose), 12 to 16 px.
- Roar shockwave: a 26 x 22 px crest, 3 to 4 frames.
- Lightning: a ground marker ring, plus a 44 px-wide bolt column that tiles
  vertically, 2 to 3 frames.
- Fury pillar: an 82 px-wide fire column that tiles vertically, a floor warning
  stripe, and a teal safe-lane marker.
- Amrit glow: 40 px, pulsing. Regrow sparkle, `GUARDED` clink spark and
  head-burst explosion.
- Optional: a Lanka palace backdrop (960 x 540) to replace the arena's
  polygon towers.
