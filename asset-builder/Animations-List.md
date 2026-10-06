# Animations list

Keyframe animations for approved sprites. A sprite must be picked (see `Sprites_List.md`)
before it can be animated.

## How to use this list

- Generate frames: `python -m ab frames <sprite> <anim> "pose 1" "pose 2" ...`
  - If `poses/<anim>.txt` exists, pass no poses and the file is used. To use a file under
    a different animation name, pass `--poses <file>`.
- Review `out/<sprite>/<anim>/sheet.png` and `preview.gif` with the user. Redo bad poses
  with `--only N`. When the user approves, run `python -m ab keep <sprite> <anim>`. That
  writes `sprites/<sprite>/<anim>/` (frames, `strip.png`, `preview.gif`).
- **These are keyframes, 2 to 5 strong poses each.** Frames are registered on the
  sprite's anchor (the feet, or the body centre for flyers). Jump height, bobbing, hit
  flashes, tints and glows are added in Godot.
- **Use the animation names below exactly.** The boss scripts play these names when they
  exist in the `SpriteFrames` (Ravan/Swaminathan does this already). The player and
  enemies will be wired to the same names.
- `--free-palette` is required whenever new colours appear: flames, sparks, glow eyes,
  ash. Without it, colours are locked to the sprite's palette.
- Column key:
  - **F:** keyframe count.
  - **Loop:** loop, once, or hold (hold the last frame).
  - **Poses:** a `poses/` file or the inline poses to pass.
- Priorities (P0/P1/P2) are the same as in `Sprites_List.md`. Tick an animation after `keep`.

---

## Siya (`siya`, approved)

Movement is run-only (240 units/s), so she has no walk cycle. Hurt invulnerability blink
and the dash i-frame tint are done in code.

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `idle` | 3 | loop | `poses/idle.txt`. Unlit sparkler held loosely in the front hand. |
| [x] | P0 | `run` | 4 | loop | `poses/run.txt` |
| [x] | P0 | `jump` | 5 | once | `poses/jump.txt`. In Godot, choose the frame by vertical velocity: 1-2 take-off, 3 apex, 4 fall, 5 land. |
| [x] | P0 | `dash` | 3 | once | The rocket dash. Used for ground and air dash. Use `--free-palette` for the flame. Poses: "Launch: gripping a lit rocket in both hands at arm's length, feet leaving the ground, body pulled forward" / "Ride: body stretched horizontal behind the rocket, both hands on it, legs trailing together, hair and sari streaming back" / "Brake: rocket gone, front foot planted and skidding, body upright, arms out for balance" |
| [x] | P0 | `lash` | 3 | once | The J sparkler whip, on the ground. `poses/fuljadi.txt`, with `--free-palette` for the sparks. Hit timing is on frame 2. |
| [x] | P0 | `air_lash` | 2 | once | The J whip in the air. Poses: "In the air, knees tucked, lit sparkler raised behind the head" / "In the air, arm whipped forward and down, sparkler pointing ahead at full reach, legs trailing". Use `--free-palette`. |
| [x] | P0 | `skyshot` | 3 | once | The L key. She fires one rocket forward and gets recoil. Use `--free-palette`. Poses: "Holding a rocket level at hip height in both hands like a launcher, fuse lit, leaning in" / "Rocket leaving her hands forward with a flash, her body jolted back by the recoil, back foot sliding" / "Recovering upright, hands still forward, slight smile". The flying rocket is `fx-skyshot`. |
| [x] | P0 | `chakri_charge` | 2 | loop | The K key, held for up to 1 s. Use `--free-palette`. Poses: "Crouched, spinning a chakri on one raised fingertip above her head, other hand on her hip" / "Same crouch, chakri lower and tilted, sparks flying". |
| [x] | P0 | `chakri_release` | 3 | once | Released K. The chakri spins around her (`fx-chakri-spin`). Use `poses/chakri.txt`, with `--free-palette`. |
| [x] | P0 | `hurt` | 2 | once | `poses/hurt.txt`. Code adds the knockback and blink. |
| [x] | P0 | `death` | 3 | hold | `poses/death.txt`. Comic, not grim: add "dazed swirl eyes" to the last pose. |
| [x] | P1 | `light_diya` | 2 | once | The E key at a diya, while grounded. Poses: "Kneeling on one knee, touching the lit sparkler tip to a small diya on the ground in front of her" / "Standing back up, smiling, sparkler raised". |
| [x] | P1 | `victory` | 3 | once | Level finish and boss win. Poses: "Both arms raised, sparkler held high, jumping with joy" / "Landing, fist pump, grinning" / "Hands on hips, proud". |
| [x] | P2 | `talk` | 2 | loop | For cutscenes. Poses: "Standing, one hand gesturing while talking, mouth open" / "Same, mouth closed". |
| [x] | P2 | `shocked` | 1 | hold | For cutscenes. "Leaning back, both hands up, eyes wide, mouth open in shock". |

## Robin (`robin`, P1, `--anchor center`)

The guide anims are P1. The Robin strike is P2 (cut, per `../TODO.md`). The boss fight
anims are P2 and depend on the fight being built.

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P1 | `fly` | 4 | loop | `poses/fly.txt` |
| [x] | P1 | `hover` | 2 | loop | Poses: "Hovering in place, wings raised, beak closed" / "Hovering, wings down, beak closed". |
| [x] | P1 | `hint` | 2 | loop | Shown next to new hazards. Poses: "Hovering, one wing pointing forward, beak wide open talking" / "Hovering, wing pointing, beak closed, eyebrow raised". |
| [x] | P1 | `perch` | 2 | loop | Sitting on Siya's shoulder or a ledge in cutscenes. Poses: "Perched, wings folded, feet gripping" / "Perched, head tilted, blinking". |
| [x] | P2 | `peck` | 3 | once | The Robin strike. Poses: "Wings pulled back, beak aimed forward, body coiled" / "Darting forward, beak jabbing, wings swept back" / "Bouncing back, wings flared". |
| [x] | P2 | `dive` | 3 | once | Boss fight. Poses: "Wings folded tight, diving steeply down-forward" / "Pulling out of the dive, wings flaring wide" / "Swooping level, wings spread". |
| [x] | P2 | `drop_sparks` | 2 | once | Boss fight. Use `--free-palette`. Poses: "Hovering, tail flicking down, a spray of sparks falling below" / "Wings up, sparks trailing". |
| [x] | P2 | `hypnotised` | 2 | loop | Use `--free-palette`. Poses: "Hovering stiffly, eyes replaced by purple spirals, beak open" / "Same, spirals turned the other way". |
| [x] | P2 | `dizzy` | 3 | once | The dizzy meter is full. Poses: "Wobbling in the air, eyes as X marks, feathers ruffled" / "Tumbling sideways, wings limp" / "Lying on his back on the ground, little stars circling (separate fx)". |
| [x] | P2 | `wake` | 2 | once | Poses: "Sitting up, shaking his head" / "Hopping up, wings out, determined". |

## Raj (`raj`, P1)

Used only in cutscenes and in the palace finale, inside his cage.

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P1 | `sulk` | 2 | loop | Poses: "Sitting cross-legged with arms folded, pouting, looking away" / "Same, sighing, shoulders dropped". |
| [x] | P1 | `dramatic` | 3 | loop | Poses: "Standing, back of one hand pressed to his forehead, swooning backward" / "Kneeling, both hands clasped, pleading upward" / "Gripping imaginary bars, face pressed forward, crying comically". |
| [x] | P1 | `freed` | 2 | once | Poses: "Arms flung wide in relief, beaming" / "Bowing theatrically to Siya". |

## Enemies

Hurt is a colour flash in code. Until a `death` anim exists, play `fx-poof` and remove the
enemy.

### Basic rakshas / guard (`basic-rakshas`, approved; `enemy.gd`: patrol, chase, attack, hurt, dead)

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `walk` | 4 | loop | `poses/walk.txt`. Used for patrol and chase; speed up the playback in chase. |
| [x] | P0 | `attack` | 4 | once | `poses/attack.txt`, mace swing. Strike is frame 2. |
| [x] | P1 | `idle` | 2 | loop | Poses: "Neutral stance, mace low" / "Same, twirling his moustache with the free hand". The twirl is the comic tell from the proposal. |
| [x] | P1 | `death` | 3 | hold | `poses/death.txt` |

### Ground shooter (`ground-shooter`, P0; `ground_shooter.gd`: patrol, charging, recovery)

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `walk` | 4 | loop | `poses/walk.txt`, blowpipe held across the body. |
| [x] | P0 | `charge` | 2 | loop | 0.65 s wind-up, which J can interrupt. Poses: "Planted, blowpipe raised to his lips aimed forward, cheeks puffing up" / "Same, cheeks fully ballooned, eyes squeezed". The purple charge ring is code or fx. |
| [x] | P0 | `fire` | 1 | once | "Blowpipe aimed forward, cheeks deflated, recoiling back a step". |
| [x] | P0 | `recovery` | 2 | loop | 1.6 s reload. Poses: "Bent over, coughing, blowpipe lowered" / "Same, loading a dart into the blowpipe". |
| [x] | P1 | `death` | 3 | hold | `poses/death.txt` |

### Brute (`brute`, P0; `enemy.gd` with a long orange wind-up and a 2-damage strike)

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `walk` | 4 | loop | `poses/walk.txt`, a heavy stomp. |
| [x] | P0 | `attack` | 4 | once | `poses/attack.txt` with the club. Hold frame 1 for the long wind-up (code tints it orange). Strike is frame 2. Frame 4 should read as "panting, club dragging", which is the punish window. |
| [x] | P1 | `idle` | 2 | loop | Poses: "Club on shoulder, chest heaving" / "Same, scratching his belly". |
| [x] | P1 | `death` | 3 | hold | `poses/death.txt`. Make it a big comic flop. |

### Winged forest demon (`winged-forest-demon`, approved; `flying_enemy.gd`: patrol, charging, recovery)

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `fly` | 4 | loop | `poses/fly.txt` |
| [x] | P0 | `charge` | 2 | once | 0.45 s wind-up. Poses: "Wings raised high, body drawn back, claws forward, glaring" / "Same, wings at peak, mouth open in a screech". |
| [x] | P0 | `dive` | 2 | loop | Poses: "Body stretched forward like a dart, wings swept back, claws extended" / "Same, wings tucked tighter". |
| [x] | P0 | `recovery` | 2 | loop | Poses: "Flapping upward clumsily, dazed, wings uneven" / "Wings down, shaking head". |
| [x] | P1 | `death` | 2 | hold | Poses: "Wings crumpled, tumbling" / "Spiralling down, eyes as X marks". |

## Khara (`khara`, P0; `docs/bosses/boss1-khara.md`)

The gada is a separate sprite that code rotates, so these poses have an empty fist. Write
each pose as if he grips a handle in that position. Code adds the colour tells: orange
wind-up, dim blue-grey recovery and red phase 2. Timings are the phase 1 values.

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `idle` | 2 | loop | Poses: "Heavy stance, fist forward at chest height, chest heaving" / "Same, shoulders lifted on an inhale". |
| [x] | P0 | `walk` | 4 | loop | `poses/walk.txt`. Slow stomp at 75 units/s; play 1.4x faster in phase 2. |
| [x] | P0 | `slam_windup` | 2 | hold | 0.85 s. Poses: "Both fists lifted high behind his head, gripping, knees starting to bend" / "Fists at the top of the swing behind his head, back arched, knees bent, teeth gritted". |
| [x] | P0 | `slam_impact` | 1 | once | 0.12 s. "Bent deep forward, both fists driven down to knee height in front of him, as if a mace has hit the ground about 50 units ahead". |
| [x] | P0 | `slam_recovery` | 2 | loop | 1.1 s, the punish window. Poses: "Bent forward, pulling backward with both fists low, straining" / "Same, leaning further back, sweating, tongue out". |
| [x] | P0 | `ladi_cast` | 3 | once | 0.5 s. Use `--free-palette` for the ember. Poses: "Crouching, unrolling a string of red firecrackers along the ground" / "Crouched, holding a glowing incense stick to the end of the string" / "Rising, incense stick held up". |
| [x] | P0 | `ladi_recovery` | 2 | once | 0.6 s. Poses: "Standing, both fingers jammed in his ears, eyes squeezed shut" / "Same, peeking with one eye". |
| [x] | P1 | `intro_roar` | 3 | once | 1.0 s. Poses: "Beating his chest with both fists" / "Fist raised to the sky, roaring" / "Back to a heavy stance, glaring". |
| [x] | P1 | `phase_shift_roar` | 3 | once | 1.2 s. Poses: "Hunched, fists clenched, shaking with rage" / "Arms flung wide, roaring at the sky, steam from his nostrils" / "Settled into a lower, angrier stance". Pair with the `fx-flame-crown` overlay. |
| [x] | P0 | `death` | 4 | hold | 1.4 s. Poses: "Staggering backward, eyes wide" / "Toppling back, arms flailing" / "Falling flat on his back" / "Lying flat, eyes as X marks, moustache drooping". |

The gada (`khara-gada`) has no animations. The phase 2 flame crown is an effect, listed
below.

## Swaminathan (code: Ravan; `docs/bosses/boss2-ravan.md`)

The script already plays these names on each `Art` `AnimatedSprite2D`. Code adds the
colour halos, the head rotation on knockout and the regrow scaling.

### Body (`swaminathan`, P0)

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `idle` | 2 | loop | Poses: "Hands on hips, arms fanned behind, chest raised" / "Same, chest dropped slightly". |
| [x] | P0 | `exposed` | 2 | loop | Staggered and slumped, belly bare. Code moves him 6 units down. Poses: "Slumped forward, arms hanging, knees buckled" / "Same, swaying". Keep the navel clear. |
| [x] | P0 | `dying` | 4 | once | Poses: "Arms flung up, recoiling" / "Knees buckling" / "Kneeling, arms limp" / "Collapsing forward". |
| [x] | P0 | `dead` | 1 | hold | "Collapsed in a heap, arms splayed". Code dims it. |
| [x] | P1 | `intro` | 3 | once | Poses: "Seated low, arms folded" / "Rising, arms spreading" / "Standing tall, all arms fanned wide". |
| [x] | P1 | `roar` | 3 | once | Phase transition. Poses: "Arms pulled in, clenched" / "All arms flung out" / "Arms raised high". |
| [x] | P1 | `fury` | 2 | loop | Use `--free-palette`. Poses: "All arms raised high, fists glowing" / "Same, arms shifted". |

### Head (`swaminathan-head`, P0; one set shared by all ten heads)

The telegraph is a moustache twirl, which is the proposal's tell. The heads lunge and
droop in code, so these frames only need the face.

| Done | Pri | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- |
| [x] | P0 | `idle` | 2 | loop | Poses: "Smug, eyes open" / "Smug, blinking". |
| [x] | P0 | `telegraph` | 3 | loop | Use `--free-palette` for the eye glow. Poses: "Mouth opening, eyes starting to glow, moustache tips curling up" / "Moustache tips twirled into tight spirals, eyes glowing" / "Mouth wide, eyes blazing". Must read under gold, orange, purple, cyan and rose halos. |
| [x] | P0 | `attack` | 2 | once | Poses: "Mouth gaping wide, jaw forward (breath, spit or roar)" / "Same, eyes crackling with lightning". |
| [x] | P0 | `exhausted` | 2 | loop | The punish window. Poses: "Drooping, eyes half closed, tongue out, moustache limp" / "Same, wobbling". |
| [x] | P0 | `knocked_out` | 1 | hold | "Limp, eyes as X marks, mouth open, moustache drooping". Code darkens and rotates it. |
| [x] | P1 | `regrow` | 3 | once | Use `--free-palette`. Poses: "Small glowing bud of a head" / "Head half formed, sparkles" / "Fully formed, smug". Code scales it from 0.3 to 1. |
| [x] | P1 | `fury` | 2 | loop | Use `--free-palette`. Poses: "Eyes ablaze, teeth bared, moustache bristling" / "Same, flames at the crown". |
| [x] | P1 | `destroyed` | 3 | once | Use `--free-palette`. Poses: "Head cracking with light" / "Bursting into firework sparks" / "Smoking crown falling". |
| [x] | P2 | `faces` | 10 | none | The per-head expressions from `Sprites_List.md`, one pose each. Used as each head's `idle`. |
| [x] | P2 | `burnt` | 1 | none | Phase 3 option from the proposal: "Same head, moustache singed to smoking stubs, furious". |

## Props and effects

Each needs a base sprite first (see `Sprites_List.md` sections 4 and 5). Use
`--free-palette` and `--no-drift-check` on all of them, because effects change size by
design.

| Done | Pri | Sprite | Anim | F | Loop | Poses / notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | P0 | `fx-diya-flame` | `burn` | 3 | loop | Flame leaning left / tall / leaning right. |
| [ ] | P1 | `fx-diya-flame` | `ignite` | 2 | once | "Bright flare burst" / "Settling flame". Plays when a diya is lit. |
| [ ] | P0 | `fx-sparkler` | `burn` | 3 | loop | Sputtering spark sprays with different shapes. |
| [ ] | P0 | `fx-lash` | `swipe` | 3 | once | Arc forming / full arc / arc fading into embers. |
| [ ] | P0 | `fx-skyshot` | `fly` | 2 | loop | Flame long / flame short. |
| [ ] | P0 | `fx-pop` | `burst` | 4 | once | Small flash / full starburst / scattered sparks / smoke wisps. |
| [ ] | P0 | `fx-dash` | `burn` | 3 | loop | Exhaust flame flicker. |
| [ ] | P0 | `fx-chakri-spin` | `spin` | 3 | loop | The wheel rotated by thirds, with the spark ring shifting. |
| [ ] | P1 | `fx-chakri-charge` | `swirl` | 3 | loop | Sparks swirling inward. |
| [ ] | P0 | `fx-bolt` | `fly` | 2 | loop | Purple bolt pulsing. |
| [ ] | P0 | `fx-poof` | `burst` | 4 | once | Puff forming / big puff with confetti / breaking up / last wisps. |
| [ ] | P0 | `fx-ladi-pop` | `burst` | 4 | once | 0.16 s. Flash / sparks up / sparks falling / smoke. |
| [ ] | P1 | `fx-fuse` | `sputter` | 3 | loop | |
| [ ] | P0 | `fx-shockwave` | `roll` | 3 | loop | Dust crescent rolling. |
| [ ] | P1 | `fx-slam` | `burst` | 4 | once | Dust burst / cracks / dust settling / cracks only. |
| [ ] | P1 | `fx-flame-crown` | `burn` | 4 | loop | Khara phase 2. |
| [ ] | P0 | `fx-roar` | `roll` | 3 | loop | Gold crest. |
| [ ] | P0 | `fx-lightning-mark` | `pulse` | 2 | loop | Ground ring. |
| [ ] | P1 | `fx-amrit` | `pulse` | 3 | loop | Green nectar orb. |
| [ ] | P1 | `fx-head-burst` | `burst` | 4 | once | Big firework explosion. |
| [ ] | P1 | `room-door` | `cleared` | 1 | none | The cleared door state. |
| [ ] | P0 | `ui-heart` | `empty` | 1 | none | Cold, unlit diya. |
| [ ] | P0 | `ui-ammo` | `empty` | 1 | none | Greyed-out rocket. |

## Animated tiles

Textures don't go through `frames`. Generate 2 or 3 tiles with the same brief and pick
ones that line up. If that fails, animate the scroll or UVs in a shader instead (often
easier).

- [ ] **P1 `river-water`:** gentle ripple loop, 3 tiles.
- [ ] **P1 Fire breath and fury pillar strips:** 2-tile flicker, or a shader scroll.
