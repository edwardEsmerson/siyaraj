# Sprites list

Every still image Siyaraj needs: characters, enemies, bosses, props, effects, UI, tiles and
backgrounds. Animations for these sprites are in `Animations-List.md`. Work through this
file first, because a sprite has to be approved before it can get keyframes.

## How to use this list

- Read `skills/siyaraj-assets/SKILL.md` first. It covers the commands, the canonical scale
  (1 game unit = 2 art px, everything placed at scale 0.5) and the `--role` sizes.
- Run commands from `asset-builder/` with `~/ml/bin/python -m ab ...`.
- `sprite` makes 4 candidates. Show the user `out/<name>/sheet.png` and let them pick.
  Never pick for them. Then `python -m ab pick <name> <id>`.
- Tick an item when it is picked (sprites) or copied into `textures/<area>/` (textures).
- Do P0 first, then P1, then P2.
  - **P0:** needed for a shippable game.
  - **P1:** story and jam themes (comic, twist, light).
  - **P2:** only if there is time.
- The briefs below are starting points. Keep them concrete. The tool adds the
  style, background and framing text automatically.
- Use `--style siya basic-rakshas` for anything new. That makes it match the approved
  pixel style.

## Decisions this list assumes

As of 2026-10-06, from `../TODO.md`:

- **The final boss is Swaminathan.** The code calls the ten-headed fight "Ravan"
  (`scenes/bosses/ravan/`). The rename is a code task. The art is Swaminathan: ten heads,
  and every head has his big twirlable moustache.
- **Level order:** forest, then river/ghats, then palace.
- **Enemy damage is a colour flash done in code.** Enemies get no hurt frames.
- **The Robin boss fight is not built yet.** Robin's guide art is P1. His fight art is P2.

## Budget

Spend is capped at Rs25,000; `python -m ab doctor` shows the running total and any batch jobs.
Prices:

- Pro, 2K image: about Rs12. A 4-candidate 2K sprite costs about Rs50.
- Pro, 4K image: about Rs22. A 4-candidate 4K boss costs about Rs90.
- Flash: about Rs9 (2K) / Rs14 (4K). `--split pro,flash` averages the two.
- `--batch` (Vertex batch, results in minutes to hours): half of the above. Use it for whole
  animation lists and texture sets.

Everything in both lists, including retries, should come to about Rs6,000 to Rs8,000 live, or
roughly half through batch.

---

## 1. Characters

- [x] **Siya** (`siya`, hero 80). Approved.
- [x] **P1 Robin** (`robin`, flyer, `--height 48 --anchor center`). Approved firebird design.
  - Siya's small bird companion. Later he gets hypnotised and becomes a boss.
  - Brief: "Robin, a tiny plump songbird companion. Round body, short tail cocked up,
    big expressive eye with a white highlight, short pointed beak. Warm marigold-orange
    breast and face. Warm brown back. Turquoise wing tips and tail tip. Tiny hot-pink
    scarf knotted at the neck. Two thin legs tucked. Side profile facing right, hovering
    with the wings half raised. Cheeky, alert expression."
- [x] **P1 Raj** (`raj`, hero 80)
  - The captive and comic foil. He is the only clean-shaven man in the game, and he
    sulks about it.
  - Brief: "Raj, clean-shaven young adult man, slim and theatrical. Black hair in a
    tall dramatic quiff. Turquoise kurta with a gold placket and buttons, cream
    churidar, a long hot-pink stole over one shoulder, embroidered juttis. Strict
    right-facing side profile, standing upright with his chin raised and one hand on
    his chest. Vain, wounded expression. No moustache or beard."
  - Pass `-r refs/characters/siya-alt-portrait.jpg` only if the style drifts.
    His identity comes from the brief.

## 2. Enemies

The proposal says enemies are palette and behaviour swaps of a few bases. Siya kills
these, so keep them readable and comic rather than scary.

- [x] **Basic rakshas / guard** (`basic-rakshas`, enemy 88). Approved.
  - Code: `scenes/enemies/enemy.tscn`. Uses the mace.
- [x] **Winged forest demon** (`winged-forest-demon`, flyer 80, blue key). Approved.
  - Code: `scenes/enemies/flying_enemy.tscn`.
- [x] **P0 Ground shooter** (`ground-shooter`, enemy 88)
  - Code: `scenes/enemies/ground_shooter.tscn`. It stops, charges, then fires a slow
    purple homing bolt. The placeholder is pink with a purple charge ring.
  - Make it a variant of the basic rakshas, so the two read as one family.
  - Command: `-r sprites/basic-rakshas/sprite.png --style basic-rakshas siya`
  - Brief: "Same rakshas footsoldier family as attachment 1: plum-purple skin, curled
    black moustache, hooked nose, small gold crown. Leaner build. Violet and turquoise
    dhoti and drape instead of pink. No mace. He holds a short bamboo blowpipe with a
    brass mouthpiece in both hands, level and pointing forward. Strict right-facing
    profile, knees bent, alert."
- [x] **P0 Brute** (`brute`, brute 136)
  - Code: `scenes/enemies/brute.tscn`, using the `enemy.gd` script. 6 HP. A long orange
    wind-up, then a heavy 2-damage strike. The placeholder has a belt, a buckle and
    bracers.
  - Command: `-r sprites/basic-rakshas/sprite.png --style basic-rakshas siya`
  - Brief: "Rakshas brute, same family as attachment 1 but huge. Broad hunched
    shoulders, thick arms, round belly, short legs. Deep maroon skin, two short curved
    ivory horns, a thick bushy black moustache, angry underbite with two tusks. Wide
    gold belt with a big round buckle, chunky gold bracers on both forearms, marigold
    and hot-pink dhoti. Holds a heavy wooden club studded with brass, resting on his
    forward shoulder. Strict right-facing profile, wide stance."
- [ ] **P2 Palace guard palette** (no new art). Recolour `basic-rakshas`, `ground-shooter`
  and `brute` for the palace with a shader or a palette swap in Godot. Use royal colours:
  white and gold uniforms with turquoise sashes. The palace placements are
  `SanctumGuard`, `RoofShooter` and `CourtyardBrute` in `scenes/levels/palace.tscn`.

## 3. Bosses

### Khara (mid boss, `docs/bosses/boss1-khara.md`)

- [x] **P0 Khara body** (`khara`, boss 200; 4K is automatic)
  - About 96 game units tall, and his horns reach 110. That is about 200 to 220 art px.
    His feet are at the root, and he faces right.
  - **Draw him without the gada.** The gada is a separate sprite that code rotates
    around his fist.
  - Command: `-r refs/characters/rakshasa-court-painting.webp --style basic-rakshas siya`
  - Brief: "Khara, rakshasa lord of the forest outpost. Massive heavy brawler, barrel
    chest, thick neck, slightly bowed legs. Dark indigo-blue skin. Two large curved
    bull horns. Wild black hair, a huge upturned moustache, a scowl and fangs. Bronze
    armour plates on the shoulders and chest, a tiger-skin waist wrap, marigold dhoti,
    heavy gold anklets. His forward right fist is raised to chest height, closed around
    nothing, as if gripping a weapon handle. His left hand hangs open. No weapon.
    Strict right-facing profile, heavy planted stance."
- [x] **P0 Khara's gada** (`khara-gada`, `--height 120 --anchor center`)
  - Brief: "Bronze gada mace on its own: a large ribbed round head with a pointed top
    finial and a long bronze handle with a grip wrap. Vertical, head up. No hand."
  - In Godot it pivots at Khara's fist: `Visual/Gada`, 14 units forward and 70 up. Set
    the sprite offset so the bottom of the handle sits on the pivot.

### Swaminathan (final boss; code: Ravan, `docs/bosses/boss2-ravan.md`)

In game he is **one full-body sprite per head state** (`state_10` down to `state_00`);
heads are severed right to left. The separate body and head below are the approved
model those state sprites were built from.

- [x] **P0 Swaminathan body states** (`swaminathan-full`, big-boss, `--height 410` re-clean)
  - State 10: `ab sprite` with `--style none -r <layout>`, where the layout reference placed
    the approved `swaminathan` body and the ten `swaminathan-head/faces` on curving necks
    over the collar (Mada to Chitta, left to right). Body at the approved body's scale.
  - States 9 to 0: `~/ml/bin/python tools/swaminathan_states.py` (from the repo root) cuts
    the rightmost heads off state 10 and caps the neck stumps, so every state is
    pixel-identical apart from the lost heads. Sources in `sprites/swaminathan-full/states/`.
  - Game export: `assets/sprites/swaminathan-states/state_NN.png`, 464 x 384 art px, feet at
    the bottom centre; head offsets in `scripts/bosses/ravan/ravan_body.gd`.

- [x] **P0 Swaminathan body** (`swaminathan`, big-boss, `--height 260`)
  - Body canvas 192 x 160 game units, which is about 384 x 320 art px. The origin is
    at the bottom centre, between his feet.
  - Keep his navel clear: code draws the amrit glow at (0, -36) units, which is
    72 art px above his feet. The shoulder line is at -118 units (236 art px).
  - **Generate him headless.** Heads are separate nodes.
  - Command: `-r refs/characters/trishiras-three-headed-rakshasa.jpg --style basic-rakshas siya`
  - Brief: "Swaminathan, a vain rakshasa king, body only. A wide ornate gold collar
    sits where his heads will attach later. No head is drawn. Broad royal torso with
    a bare belly and a visible navel, eight arms fanned out behind two main arms
    held on his hips. Purple-black skin, gold armlets, a hot-pink and gold silk dhoti,
    a turquoise sash, heavy jewelled belt, pointed gold shoes. Front three-quarter
    stance, feet planted wide."
  - If a headless result keeps failing, generate him with one head and erase it by
    hand. The `exposed` frames need the belly bare.
- [x] **P0 Swaminathan head, base** (`swaminathan-head`, `--height 76 --anchor center`)
  - Code canvas 48 x 48 game units (96 art px). The origin is the face centre, and the
    mouth is 10 units (20 art px) below it. The hurtbox is a 17 unit circle.
  - Brief: "One crowned rakshasa king's head on its own. A tall pointed gold crown
    with a single jewel, pointed ears with gold earrings, purple-black skin. A HUGE
    black handlebar moustache with curled tips, twice the width of the face. Heavy
    eyebrows, smug expression. Three-quarter view facing slightly down. A short neck
    stub at the bottom."
  - The ten heads share this crown, ears and moustache.
- [ ] **P2 Ten head variants**. Make them as one `frames` call on the base head, with one
  pose per head, instead of ten new sprites, so the identity holds:
  `python -m ab frames swaminathan-head faces "smug, ..." "furious, ..." ...`
  - One expression per head:
    - 0 Mada: smug
    - 1 Krodha: furious
    - 2 Lobha: grasping, licking his lips
    - 3 Moha: hazy, half-lidded
    - 4 Matsarya: glancing sideways, jealous
    - 5 Ahamkara: haughty, nose up
    - 6 Manas: restless, darting eyes
    - 7 Kama: winking, alluring
    - 8 Buddhi: calm
    - 9 Chitta: stern
  - Until then, code tints the base head per jewel and attack colour.

## 4. Props and level objects

- [x] **Fuljadi** (`fuljadi`, prop 40). Approved.
- [x] **Rocket** (`rocket-weapon`, prop 40). Approved.
- [x] **Chakri** (`chakri-weapon`, prop 40). Approved.
- [ ] **P0 Diya** (`diya`, `--height 32`)
  - This is the checkpoint. The levels use a Bowl and Flame node pair: 11 in the forest
    and 5 each in the river and palace.
  - Brief: "Small clay diya oil lamp, terracotta bowl with a pinched spout, painted
    with a white and hot-pink dot border. Unlit, with a dark wick. Side view." The flame
    is a separate effect (see section 5).
- [ ] **P0 Room door** (`room-door`, `--height 96`)
  - Forest side-room doors: Root chamber and Canopy nest, 6 doors in total. The player
    presses E to enter.
  - Brief: "A small arched wooden door set into a tree trunk, carved marigold frame,
    iron ring handle, one hanging marigold garland. Front view."
  - Make a "cleared" version with frames: "same door, garland lit with a small
    turquoise ribbon tied on". Code shows `CLEARED`.
- [ ] **P0 Level finish gate** (`toran-gate`, `--height 160`)
  - This replaces the placeholder `Flag`/`Post` at each level's end.
  - Brief: "Festive toran archway, two carved wooden posts with a marigold-and-mango-leaf
    string garland hung between them, small brass bells. Front view."
- [ ] **P0 Ladi cracker** (`ladi-cracker`, `--height 28 --anchor center`)
  - Khara's firecracker string. Game size is 8 x 14 units.
  - Brief: "One small red paper firecracker tube with a gold paper band and a short
    gold wick. Vertical."
- [ ] **P1 Ladi cord** (`texture ladi-cord --mode tile --tile 32`): a braided red cord
  that the crackers hang from, tiled horizontally.
- [ ] **P1 Raj's cage** (`raj-cage`, `--height 140`)
  - For the palace finale and the ending.
  - Brief: "An ornate hanging gold birdcage big enough for a man. Onion-dome top, bars
    with small hot-pink tassels, a padlock shaped like a moustache. Empty, front view."
- [ ] **P2 Breakable wall** (`weak-wall`, `--height 128`)
  - Only if the proposal's "rocket dash breaks weak walls" gets built.
  - Brief: "Cracked mud-brick wall section with a painted warning swirl."

## 5. Effects

Effects are separate sprites, so firework light never gets baked into characters. Make
each one with `sprite` (`--anchor center`), pick a base, then animate it with
`frames --free-palette` (see `Animations-List.md`). Sizes are given in game units, then
art px.

**Siya's weapons**

- [ ] **P0 Sparkler sparks** (`fx-sparkler`, `--height 24`): the burning tip of the lit
  fuljadi. A spray of white-gold sparks.
- [ ] **P0 Lash arc** (`fx-lash`, `--height 80`): a crescent of gold sparks and a trail,
  the swipe of the sparkler whip.
- [ ] **P0 Skyshot rocket in flight** (`fx-skyshot`, `--height 48`)
  - The projectile is a radius 4 circle that moves at 640 units/s.
  - Brief: "Small paper rocket flying right, a short orange flame and a smoke puff
    trail behind it."
  - The code currently draws an orange trail and circles (`scripts/combat/skyshot_projectile.gd`).
- [ ] **P0 Pop burst** (`fx-pop`, `--height 48`): the skyshot impact, an orange and
  white starburst. It also works as the generic hit spark (`scripts/effects/burst.gd`).
- [ ] **P0 Rocket dash flame** (`fx-dash`, `--height 40`): a horizontal rocket exhaust
  flame and sparks behind Siya (`scripts/effects/dash_trail.gd`).
- [ ] **P0 Chakri spin** (`fx-chakri-spin`, `--height 64`)
  - The spinning chakri wheel with a ring of pink and turquoise sparks. It orbits Siya
    within a 110 unit radius.
- [ ] **P1 Chakri charge glow** (`fx-chakri-charge`, `--height 48`): small sparks
  swirling while K is held.

**Enemies**

- [ ] **P0 Enemy bolt** (`fx-bolt`, `--height 24`): the purple homing bolt from
  `homing_projectile.tscn`, used by the ground shooter and Swaminathan's Lobha/Kama
  heads.
- [ ] **P0 Enemy shot** (`fx-shot`, `--height 20`): the rose shot from
  `enemy_projectile.tscn`, used by Swaminathan's spread shot. A recolour of the bolt is
  fine.
- [ ] **P0 Enemy death puff** (`fx-poof`, `--height 72`)
  - A cartoon smoke puff with sparks and confetti, played when any normal enemy dies.
  - It also replaces per-enemy death animations until those exist.

**Diya**

- [ ] **P0 Diya flame** (`fx-diya-flame`, `--height 20`): a small teardrop flame with a
  warm halo. It loops.

**Khara (sizes from the boss doc)**

- [ ] **P0 Ladi pop** (`fx-ladi-pop`, 34 x 18 units, `--height 68`): a flash with
  sparks shooting upward.
- [ ] **P1 Ladi ash** (`fx-ladi-ash`, `--height 20`): a small grey ash curl.
- [ ] **P1 Fuse spark** (`fx-fuse`, `--height 24`): a sputtering yellow spark.
- [ ] **P1 Direction chevron** (`fx-chevron`, 8 x 16 units, `--height 32`): yellow.
- [ ] **P0 Shockwave** (`fx-shockwave`, 28 x 16 units, `--height 56`): a dust crescent
  rolling along the ground.
- [ ] **P1 Slam impact** (`fx-slam`, about 120 units wide, `--height 240`): dust and
  ground cracks.
- [ ] **P1 Flame crown** (`fx-flame-crown`, `--height 64`): Khara's phase 2 overlay.

**Swaminathan (sizes from the boss doc)**

- [ ] **P0 Fire breath beam** (`texture fx-breath --mode tile --tile 64`): a loopable
  32 unit tall fire strip. Add start and end caps as `cutout`.
- [ ] **P0 Lightning bolt column** (`texture fx-lightning --mode tile --tile 88`): 44
  units wide and tiles vertically. Add a ground marker ring sprite (`fx-lightning-mark`).
- [ ] **P0 Roar shockwave** (`fx-roar`, 26 x 22 units, `--height 52`): a gold crest.
- [ ] **P0 Fury pillar** (`texture fx-pillar --mode tile --tile 164`): an 82 unit wide
  fire column that tiles vertically. Also a red floor warning stripe and a teal
  safe-lane marker.
- [ ] **P1 Amrit glow** (`fx-amrit`, `--height 80`): a pulsing green orb of nectar.
- [ ] **P1 Regrow sparkle** (`fx-regrow`) and **GUARDED clink spark** (`fx-clink`).
- [ ] **P1 Head burst** (`fx-head-burst`, `--height 120`): a big firework explosion for
  the death sequence.

## 6. UI and HUD

Use `refs/hud/health-bar.jpg` and `refs/hud/dialog-panel.jpg` as references. These are
drawn on a CanvasLayer, but the same scale still holds (art px = 2 x screen units).

- [ ] **P0 Health icon** (`ui-heart`, `--height 32`): a lit diya for full health and a
  cold, unlit diya for empty. Make the empty state with frames. Siya has 3 HP, or 5 in
  the Swaminathan arena.
- [ ] **P0 Skyshot ammo icon** (`ui-ammo`, `--height 32`): a mini rocket for full and a
  greyed-out rocket for empty. Five are shown.
- [ ] **P0 Chakri cooldown icon** (`ui-chakri`, `--height 40`): code draws the radial
  cooldown over it.
- [ ] **P0 Boss health bar frame** (`ui-boss-bar`)
  - The bar is 600 x 16 units, which is 1200 x 32 art px.
  - Make an ornate gold end cap as a sprite (`--height 48`) and a tileable middle
    (`texture --mode tile --tile 32`). Do not try to make the whole bar in one image.
- [ ] **P0 Title logo** (`ui-logo`, `--height 200`, 4K, `-n 6`)
  - Brief: "The word SIYARAJ in chunky Indian truck-art lettering, hot pink letters
    with marigold outlines and turquoise shadows, a sparkler and a rocket crossed
    behind it."
  - Text is hit and miss. Expect to regenerate.
- [ ] **P1 Dialogue panel** (`ui-dialog`): a 9-slice box with a rangoli border, a
  speaker name tab, and a speech bubble tail. Used for Robin's hints and tutorial
  prompts.
- [ ] **P1 Portraits** (`portrait-siya`, `portrait-robin`, `portrait-raj`,
  `portrait-swaminathan`, `portrait-khara`, all `--height 128 --anchor center`)
  - Bust portraits for dialogue and comic panels.
  - Use `-r sprites/<name>/sprite.png --style <name>` so each one matches its approved
    sprite.
- [ ] **P1 App icon** (`ui-icon`, `--height 128`): Siya's face with a lit sparkler, or a
  lit diya. Export at 256 for `icon.svg` / `icon.png`.
- [ ] **P2 Comic hit words**: BOOM!, ZAP!, POP!, DHAM! in Devanagari-style lettering.
  A free display font is probably easier and cleaner than generating these.
- [ ] **P2 Swaminathan head pips**: lit, hollow and teal states. Code draws them now.

## 7. Textures and backgrounds

Tiles are 128 art px (64 units) and must be checked in `NN-tiled.png` for seams. Parallax
layers are 1080 art px tall. The proposal asks for one tileset and two parallax layers per
level. Every level's terrain is grey polygons right now: `Body` for fill and `Edge` for the
top lip. Tiles are applied as `Polygon2D` textures, so each level needs a **fill** tile
and a **top-edge** strip.

### Forest (level 1, `textures/forest/`)

- [x] **Parallax layers** `j1.png` to `j4.png`. Approved.
- [ ] **P0 Ground fill** (`forest-fill`, tile): dark loamy earth with roots and small
  stones, folk-art shapes, dusky purples and browns.
- [ ] **P0 Ground top** (`forest-top`, tile)
  - Moss and grass lip with tiny marigold flowers. It must tile horizontally. The top
    third is the lip and the rest fades into the fill colour.
- [ ] **P0 Branch platform** (`forest-branch`, cutout)
  - The one-way jump-through branches: 24 `TrunkBranch` and 5 `Branch`/`Banyan`
    nodes. A horizontal banyan branch with leaves.
- [ ] **P1 Stepping stone** (`forest-stone`, cutout): mossy flat rocks for the stone
  crossing.
- [ ] **P1 Shrine dressing** (`forest-shrine`, cutout): a small ruined stone shrine
  with a bell and red cloth, for the Old shrine section.

### River and ghats (level 2, `textures/river/`)

- [ ] **P0 Far layer** (`river-far`, layer 21:9): a dusk sky in pink and orange, the
  wide river, and the far bank's temple shikharas and ghats in silhouette, with kites
  in the sky.
- [ ] **P0 Mid layer** (`river-mid`, cutout): ghat steps, temple towers, moored wooden
  boats, and chhatris with flags.
- [ ] **P1 Near layer** (`river-near`, cutout): hanging bells, marigold garlands,
  lamp posts and a ferry rope.
- [ ] **P0 Ghat stone fill** (`ghat-fill`, tile): worn sandstone blocks, warm ochre.
- [ ] **P0 Ghat stone top** (`ghat-top`, tile): a step edge with chalk rangoli dots and
  marigold petals.
- [ ] **P0 Dock plank** (`river-dock`, tile): for the `Dock`, `LowPier`, `HighPier` and
  `BridgeDeck` nodes.
- [ ] **P0 Water strip** (`river-water`, tile): a turquoise water surface with diya
  reflections. It is animated (see `Animations-List.md`). Used by `WaterLine`.

### Palace (level 3, `textures/palace/`)

- [ ] **P0 Far layer** (`palace-far`, layer 21:9): a night sky full of fireworks over
  gold palace domes and minarets.
- [ ] **P0 Mid layer** (`palace-mid`, cutout): hall arches, jharokha windows, hanging
  brass lamps and silk curtains.
- [ ] **P1 Near layer** (`palace-near`, cutout): torans, marigold strings and drapes.
- [ ] **P0 Marble fill** (`palace-fill`, tile): white marble with gold and turquoise
  inlay (pietra dura).
- [ ] **P0 Marble top** (`palace-top`, tile): a gold trim edge with a small Madhubani
  border.
- [ ] **P1 Roof tile** (`palace-roof`, tile): for the `Roof` and `LastRoof` nodes.
  Pink sandstone with gold finials.
- [ ] **P1 Pillar** (`palace-pillar`, cutout): a carved pillar for the `Pillar` nodes
  and the gate.

### Boss arenas and screens (single screen, 1920 x 1080; use `layer --aspect 16:9`)

- [ ] **P0 Khara arena** (`khara-arena`, `textures/bosses/`): a forest clearing turned
  into a rakshas outpost, with skull totems, torn tents, a crude palisade and a dusk
  sky. Reuse the forest tiles for the floor.
- [ ] **P0 Swaminathan's hall** (`swaminathan-hall`, `textures/bosses/`)
  - The arena is 960 x 540 units. It replaces the polygon towers in
    `ravan_arena.tscn`.
  - A gold throne hall, his giant moustache emblem on banners, and ten hanging lamps.
    Dark and menacing, but still in folk colours.
- [ ] **P1 Swaminathan's hall, lit** (`swaminathan-hall-lit`): the same hall during
  the Diwali finale. Every lamp is lit, there are fireworks through the windows, and
  it is bright and joyful. Pass the dark hall with `-r` so the layout matches.
- [ ] **P1 Title screen background** (`title-bg`): Siya on the ghats at dusk, looking
  at the palace far away, with fireworks.

## 8. Comic cutscene panels (P1)

The proposal wants static comic panels with speech bubbles. `ab texture --mode layer`
asks for a horizontally seamless strip, which is wrong for panels. `ab texture --mode
panel` makes one framed 16:9 illustration, not a seamless layer. Get the user's
approval on the prompt first. Pass approved sprites with repeated `-r` flags for
identity. Leave speech bubbles and text out of the art; the game draws them.

```bash
python -m ab texture intro-1 "Raj poses dramatically by the river on the eve of Diwali" \
  --mode panel -r sprites/raj/sprite.png
```

Review `out/panels/<name>/sheet.png` and let the user pick. Copy only the chosen
`NN.png` to `assets/cutscenes/<name>.png`.

- [ ] **Intro 1:** The ghats on the eve of Diwali. Raj poses heroically by the river.
- [ ] **Intro 2:** Swaminathan's guards grab Raj, who swoons dramatically.
- [ ] **Intro 3:** Siya and Robin find a trail of burnt-out sparklers. Siya grabs the
  family's firework stock.
- [ ] **Before Khara:** Khara blocks the forest path, gada on his shoulder.
- [ ] **Before Swaminathan:** Swaminathan twirls ten moustaches on his throne, and Raj
  hangs in a cage.
- [ ] **Twist (only if the Robin fight is built):** Swaminathan hypnotises Robin, whose
  eyes become spirals.
- [ ] **Ending 1:** Robin dives into Swaminathan. A flash, then Nathan Robin (a
  moustached flapping bird-man) flies off into the sunset, arguing with himself.
- [ ] **Ending 2:** Siya frees Raj while the palace lights up with fireworks.
