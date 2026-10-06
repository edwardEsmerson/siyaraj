# Boss 1: Khara, Lord of Janasthana

## Concept

Khara is the rakshasa lord of Janasthana, the demon outpost in the Dandaka forest.
In the Ramayana he is Ravana's brother and leads the forest garrison that attacks Rama after
Shurpanakha is humiliated. That makes him the right gatekeeper at the end of the
forest. He is a heavy, slow brawler with a bronze gada (mace). He also lays *ladi*, a string
of firecrackers, which pop in a chain along the ground.

Difficulty is mid-level. Both attacks have long, colour-coded tells. Each one rewards
movement the player already knows: running, the dash, timed jumps, and punishing recovery.
Every Khara hazard damages Siya through `take_damage`, so dash i-frames dodge the slam,
shockwaves and ladi pops like any enemy hit.

- Scene: `scenes/bosses/khara.tscn` (script `scripts/bosses/khara.gd`)
- Arena: `scenes/bosses/khara_arena.tscn` (F6). It uses the forest player with all three weapons.
- Hazards: `scripts/bosses/ladi_firecracker.gd`, `scripts/bosses/ground_shockwave.gd`
- Generic UI: `scenes/ui/boss_health_bar.tscn` (script `scripts/ui/boss_health_bar.gd`)
- Check: `tests/khara_boss_check.gd`

## Stats

| Stat | Value |
| --- | --- |
| Health | 24 (phase 2 at 12 or less) |
| Collider | 56 x 92 px, enemy body layer (bit 4) |
| Walk speed | 75 px/s (phase 2: 105 px/s) |
| Poise | Hits flash him but never push him or cancel an attack |
| Contact damage | None. Siya can walk or dash through him |

Damage budget: sparkler 1, skyshot 2 (5 shots = 10), full chakri 3. A fight with only the
sparkler needs 24 hits. A slam recovery leaves time for about 3 lashes.

All timings assume 60 physics frames per second. Every value is exported on the Khara root,
in the Movement, Gada slam and Ladi fireworks inspector groups.

## Moveset

### 1. Gada slam (strong attack)

| Step | Phase 1 | Phase 2 | Tell |
| --- | --- | --- | --- |
| Wind-up | 0.85 s (51 f) | 0.65 s (39 f) | Body glows orange and the gada rises overhead. An orange outlined zone fills along the ground, matching the hitbox. Label: GADA RAISED! |
| Impact | 0.12 s (7 f) | same | Red flash, DHAM! burst |
| Recovery | 1.10 s (66 f) | 0.80 s (48 f) | Body turns dim blue-grey and the gada stays in the ground. Label: STUCK - STRIKE NOW |

- Starts when Siya is within 105 px. Facing locks for the whole swing.
- Hitbox: 120 x 80 px, from 4 to 124 px in front of his centre. Deals 2 damage with a
  360/-220 knockback.
- Shockwave: on impact, a low wave (28 x 16 px) travels along the ground at 380 px/s for 1 s.
  It deals 1 damage and stops at walls. Phase 1 sends one wave forward. Phase 2 sends one
  each way.
- Counterplay: run away during the wind-up (240 px/s covers ~200 px), or dash through Khara
  to his back. Bodies do not block, and phase 1 sends no wave behind him. Then jump the wave
  and punish during recovery.

### 2. Ladi fireworks

| Step | Phase 1 | Phase 2 |
| --- | --- | --- |
| Cast (crouch, lights fuse) | 0.5 s (30 f) | same |
| Fuse | 1.2 s (72 f) | 0.9 s (54 f) |
| Crackers | 12 x 36 px = 432 px | 14 x 36 px = 504 px |
| Chain speed | 1 cracker per 0.06 s (~3.6 f), about 600 px/s | same |
| Each pop | 0.16 s (~10 f), 34 x 18 px hitbox | same |
| Recovery after placing | 0.6 s (36 f) | same |
| Cooldown | 4.5 s | 3.0 s |

- The ladi is laid 44 px in front of Khara, with its lit end there. It bursts **toward
  Siya's side** (left or right) as a chain of pops travelling away from the lit end. Each
  ladi deals at most 1 damage (220/-260 knockback, in the travel direction). Strings stop
  before walls.
- Direction tells:
  - The red crackers are physically laid out on the side the chain will travel.
  - Three yellow chevrons pulse at the lit end, pointing that way.
  - A faint yellow lane covers the full blast length.
  - A sputtering yellow spark with a countdown ring sits at the lit end.
- The string itself is harmless until the fuse finishes, so Siya can walk across it.
- Counterplay:
  - Cross to the **other side of the lit end** during the fuse.
  - Or stand beyond the end of the string.
  - Or **jump as the pop front arrives**. Pops are 18 px tall; Siya's jump apex is ~47 px,
    and she spends ~0.39 s above 18 px. A single position is dangerous for ~0.25 s.

### Phase 2 pincer

In phase 2, every ladi cast places a second, shorter string (10 crackers) at the wall on
Siya's side. It bursts back toward Khara. Its fuse is 1.6 s longer, so Siya needs two
separate jumps at least ~0.75 s apart. She can also stand behind Khara's lit end, at the
cost of being close to his next slam.

## AI and phases

States: `INTRO, IDLE, APPROACH, SLAM_WINDUP, SLAM_ACTIVE, SLAM_RECOVERY, LADI_CAST,
LADI_RECOVERY, PHASE_SHIFT, DEAD`.

1. **Intro**: 1.0 s, which keeps the arena entrance safe. The first ladi becomes available after 1.5 s.
2. **Idle**: 0.7 s (phase 2: 0.4 s). Then he decides:
   - Ladi ready and (Siya more than 210 px away, or 2 slams since the last ladi): ladi.
   - Siya within 105 px: slam.
   - Otherwise: approach.
3. **Approach**: walks toward Siya. He slams within 105 px. After 2 s of walking with the
   ladi ready, he lights a ladi instead, so kiting does not stall the fight.
4. **Phase 2** (at 12 HP or less, once): a 1.2 s (72 f) ROAR!.
   - Cancels any pending slam wind-up, a small reward for the hit that triggers it.
   - Resets the ladi cooldown, so he opens with the pincer.
   - From then on: faster walk, shorter wind-up and recovery, shorter fuse, longer string,
     double shockwave and the pincer. Every slam chains straight into a ladi when the
     cooldown allows.
   - Body tint shifts red and a crown of flames flickers above his head. The health bar
     fill turns orange.
5. **Death**: he topples and fades for 1.4 s with rolling bursts (KHARA FALLS!), then frees
   himself. Defeat defuses every remaining ladi and shockwave. Emits `died` once.

## Telegraph colour key

| Colour | Meaning |
| --- | --- |
| Orange body glow + orange ground zone | Gada wind-up: leave the zone |
| Red body flash | Slam impact |
| Dim blue-grey body | Recovery: attack now |
| Pale yellow body glow | Lighting a ladi |
| Yellow chevrons, spark and lane | Ladi direction and length |
| Red crackers → white/yellow pops → grey ash | Unlit → exploding → spent |
| Orange low wave | Shockwave: jump it |
| Pulsing red body | Phase change roar |

## Boss health bar (shared)

`scenes/ui/boss_health_bar.tscn` is boss-agnostic. Instance it under a CanvasLayer and call
`bind(boss)`, or set `boss_path`. A bound boss needs:

- `max_health`, `health` and `health_changed(remaining)`.
- Optional: `died`, `phase_changed(phase)`, `boss_name` (falls back to `enemy_name` or the
  node name) and `boss_title`.

The bar shows a delayed damage chip, tick marks at `phase_thresholds` (default 0.5) and an
enraged fill colour after a phase change. It fades out on death. Boss 2 (Swaminathan) uses it
too, with a separate head-indicator row (`scripts/bosses/ravan/ravan_head_indicators.gd`).

## Sprite and animation list for the artist

Khara is about 96 px tall at gameplay scale (horns reach 110 px), with feet at the root. He
faces right by default; code mirrors `Visual`. The gada should be a separate sprite that
pivots at his fist (`Visual/Gada`, 14 px forward and 70 px up), so code can keep rotating it
for the slam arc.

| Animation | Frames (suggested) | Loop | Notes |
| --- | --- | --- | --- |
| `intro_roar` | 6-8 | no | 1.0 s, chest-beat or gada raised to the sky |
| `idle` | 4 | yes | heavy breathing, gada resting forward |
| `walk` | 6-8 | yes | slow stomp, 75 px/s (phase 2 at 1.4x speed) |
| `slam_windup` | 5 | hold last | 0.85 s, gada lifted behind the head, knees bending |
| `slam_impact` | 2-3 | no | 0.12 s, gada head hits the ground ~50 px ahead |
| `slam_recovery` | 4 | hold | 1.1 s, gada stuck, visibly struggling to pull it free |
| `ladi_cast` | 5 | no | 0.5 s, crouch, unroll the string, light it with an agarbatti or ember |
| `ladi_recovery` | 3 | no | 0.6 s, stand back up and cover his ears |
| `phase_shift_roar` | 6 | no | 1.2 s, rage, flames appear |
| `hurt_flash` | none | n/a | handled by modulate; an optional 1-frame flinch overlay |
| `death` | 8 | no | 1.4 s, topple backward, gada drops |
| Phase 2 overlay | 4 | yes | flickering flame crown or aura |

Effects:

| Effect | Size | Frames |
| --- | --- | --- |
| Ladi cracker (unlit) | 8 x 14 px red tube with a gold wick, plus a cord tile | static |
| Ladi pop | 34 x 18 px flash with sparks above | 4-5 frames, 0.16 s |
| Ladi ash | 10 x 4 px | static |
| Fuse spark | 8-12 px, looping sputter | 3-4 frames |
| Direction chevron | 3 per ladi, about 8 x 16 px | static |
| Shockwave | 28 x 16 px dust crescent | 3-4 looping frames |
| Slam impact dust/crack | about 120 px wide | 4 frames |
| Health bar frame | 600 x 16 px with an ornate end cap | optional |

## Not yet done

- Not wired into the forest progression. `SideRooms/CanopyNest/EncounterSpawns/NestBoss`
  or the end of the forest are candidate placements for integration.
- Audio cues (fuse hiss, pop chain, gada thud) would strengthen the tells.
- Balance has been checked by automated tests, not by a human playtest.
