# Forest level art direction (diyalit)

Kit: `assets/world/forest/diyalit/`. Level: `scenes/levels/forest.tscn` (WorldSkin `direction = "diyalit"`),
boss arena `scenes/bosses/khara_arena.tscn` follows it.

## Mood

Diwali night in a sacred banyan forest. The forest is dark, cool and old (teal leaves, aubergine shadow,
violet mist); people have walked through it before Siya and left light behind: clay diyas on roots, paper
lanterns in the branches, marigold garlands on shrines. Warm light is the story. It gets sparser and
redder as Siya nears Khara's camp, where the only light is fire.

Readability first: the player and the route are the brightest, sharpest thing on screen. Background
layers are tinted back (cooler, darker, less saturated) so the playable band always wins.

## Colour script

| # | Section | World X | Light | Key colours | Feeling |
| --- | --- | --- | --- | --- | --- |
| 0 | Forest edge | 0-1500 | dusk, last peach sky | violet, peach, a few marigold diyas | invitation |
| 1 | Clearing | 1500-2850 | warmest, festival | marigold, pink, warm amber | safe, first diya |
| 2 | Broken canopy | 2850-4200 | moonlight through gaps | cool blue-teal, silver | exposed, airy |
| 3 | Root ridge | 4200-6450 | amber root glow | orange bark, teal moss | climbing, effort |
| 4 | Hollow trunks | 6450-8950 | enclosed, ember hollows | deep aubergine, ember orange | inside the forest |
| 5 | Stone crossing | 8950-10450 | cold mist on ruins | teal-grey stone, moss green | old, forgotten |
| 6 | Banyan climb | 10450-13100 | lantern canopy | many-coloured lanterns, gold | the showpiece |
| 7 | Upper ravine | 13100-15500 | high, misty, moonlit | blue-violet haze, prayer-flag colours | wind, height |
| 8 | Old shrine | 15500-17600 | sacred, pink glow | hot pink, saffron, brass | wonder |
| 9 | Last crossing | 17600-20600 | ominous ember | red-orange, black | dread |
| 10 | Khara clearing | 20600-21600 | camp fire | fire orange, bone, black | confrontation |

Side rooms: the root chamber is an underground cave of roots lit by glowing fungus (teal + amber);
the canopy nest is inside the crown of the great banyan under a starry sky (deep blue + lantern gold).

## Landmarks (one identity per section)

| Section | Landmark | Where |
| --- | --- | --- |
| Forest edge | forest gate: leaning trunks with a marigold toran and bells | over the start, Siya walks through it |
| Clearing | sacred tree hung with red threads and diyas, tulsi planter | behind the clearing diya |
| Broken canopy | fallen giant tree / broken log bridges | across the pits |
| Root ridge | root arch over the stairs, the root-chamber hollow tree | framing the door at x 5660 |
| Hollow trunks | giant hollow trunks with glowing interiors | behind the two roofs |
| Stone crossing | broken temple pillars and a fallen gateway in mist | in the pits and on the islands |
| Banyan climb | the great banyan trunk, curtains of aerial roots, lanterns | behind the branch ladder and nest door |
| Upper ravine | prayer-flag lines and carved posts | spanning gaps between platforms |
| Old shrine | small forest temple with bell and saffron flag | on the shrine branch at the top of the climb |
| Last crossing | rakshas skull totems, torn torans | at each landing |
| Khara clearing | palisade gate with skulls and torches | at the exit flag |

## Layers and rules

- **Far** (scroll 0.15, opaque): sky and distant forest; swaps per section group (dusk / moon / shrine / ember)
  with a slow crossfade, tinted by the section's colour script.
- **Mid** (scroll 0.45, cutout): tree trunks and section silhouettes (roots, hollows, ruins, banyan, shrine,
  camp); tinted darker and cooler than the playable band; never brighter than the platforms.
- **Landmarks** (z -6, behind actors, on the ground): one hero piece per screen at most.
- **Playable band**: platforms with a role-specific top: forest-floor moss on ground, gnarled root bark on
  ledges and stairs, carved stone on ruins and the shrine, banyan branches for jump-throughs.
  Every open platform edge gets an end piece; every open side of solid ground gets a side strip, so no
  rectangle edge is ever bare.
- **Dressing** (z -2): ground tufts, flowers, pots, diyas, signposts, at most 2-3 small props per 300 units,
  clustered near landmarks and landings, never on the route's take-off or landing spots.
- **Hanging** (z -2/-6): garlands, lanterns and diya strings hang from the top of the screen or from branches,
  framing gaps rather than blocking jumps.
- **Near** (scroll 1.25, in front of actors): dark fern and root silhouettes along the bottom edge only, low
  enough never to cover a platform top or Siya.
- Density follows the colour script: busiest at the clearing, banyan and shrine; sparse at the canopy,
  ravine and last crossing so those read as exposed.
- Diyas (checkpoints), doors and the finish keep clear space around them.
