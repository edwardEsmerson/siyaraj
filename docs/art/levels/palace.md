# Palace level art direction (diyalit kit)

Kit: `assets/world/palace/diyalit/`. Level: `scenes/levels/palace.tscn` (14400 x 540 units, camera fixed vertically).
Boss arena: `scenes/bosses/ravan/ravan_arena.tscn` follows the same kit.

## Mood

Diwali night inside Swaminathan's palace. Siya breaks in through the outer gate, crosses moonlit courtyards and
rooftops lit by fireworks, then goes deeper into warmer, richer and more claustrophobic halls until she reaches the
villain's throne room. The level starts cool and open and ends warm, enclosed and ominous. Light comes from diyas,
lamps and fireworks, never from a flat ambient wash. Pools of warm light mark the route.

## Colour script

| x (units) | Section | Space | Dominant | Accent | Value |
| --- | --- | --- | --- | --- | --- |
| 0 - 2350 | Palace gates | exterior, night sky | indigo sky, dusty teal stone | marigold torans | mid-dark, cool |
| 2350 - 3300 | Courtyard | exterior, open | indigo, teal | hot-pink rangoli, fountain | mid-dark, cool |
| 3300 - 5550 | Column gallery | open colonnade, sky through the arches | teal columns | brass lamps | mid, cool to warm |
| 5550 - 8850 | Broken roofs | exterior, most open | violet sky, fireworks | pink and gold bursts | brightest sky, dark silhouettes |
| 8850 - 11260 | Inner hall | interior | warm plum walls, amber light | hot-pink drapes, gold | warm, rich |
| 11260 - 13400 | Sanctum | interior | crimson-plum | brass lamp towers, bells | warm, dark, sacred |
| 13400 - 14400 | Throne approach | interior | deep aubergine | gold moustache banners | darkest, ominous |

## Section identities and landmarks

1. **Palace gates.** Siya spawns in front of the great gate (pol) and walks through its archway. The stairs climb the
   outer rampart; the lintel run is the rampart top, with a chhatri at its far end. Broken ledges drop to the courtyard.
2. **Courtyard.** A lotus fountain and a pair of elephant statues frame the brute fight; the courtyard diya sits by a
   tulsi altar. Rangoli on the floor.
3. **Column gallery.** A colonnade wall stands behind the whole section, with the sky showing through its arches.
   Real columns stand on the two column bases and hold up the gallery roof (the one-way balcony run). Hanging lamps
   in the bays.
4. **Broken roofs.** Rooftop stone and broken tiles. Chhatris on the lookout, a broken dome on the low recovery
   floor, the full skyline and fireworks behind. Fewest props, so the jumps read.
5. **Inner hall.** A warm hall wall with jharokhas and drapes. Chandeliers hang over the floor and columns stand on
   the column bases under the balcony. Curtains frame the entry.
6. **Sanctum.** A shrine wall, deepstambh lamp towers on the climb, and bells. The ascent reads as a temple stair.
7. **Throne approach.** Moustache banners, a red-carpet floor, and the throne door at the finish.

## Layers and rules

- **Far** (scroll 0.15): the night sky with fireworks and a distant skyline. No ledges or anything that reads as
  walkable.
- **Mid** (scroll 0.45): palace silhouettes. Darker and calmer than the playfield, again with nothing walkable.
- **Section walls** (world space, behind everything played on): colonnade, hall, sanctum and throne walls cover the
  sky in interiors. They are dark and low contrast, and each starts and ends behind a column or gate so no hard edge
  shows.
- **Landmarks** (behind actors): one hero landmark per screen at most, placed to frame the route (gates you pass
  through, columns that hold up the balconies). They never cover a diya, door or the finish.
- **Props** (on surfaces): clustered in twos and threes at the foot of walls, landmarks and stairs, never spread
  evenly. Platform middles and jump take-offs stay clear. Roofs get the fewest props.
- **Foreground** (in front of actors): rare dark silhouettes (a column, a drape edge, a chandelier chain). There is
  at most one per screen and it never sits over a landing or an enemy.
- **Platform edges**: every surface has a gold-trimmed cap. Exposed ends get a carved pilaster end piece, floating
  slabs get corbels or broken beams underneath, one-ways are jharokha balconies, and foundations darken with depth.
  Each section has its own top and fill: stone (gate, courtyard, gallery), roof (roofs), hall marble (hall, sanctum,
  throne).
- **Light**: additive warm glow pools behind diyas, lamps and chandeliers, so the brightest warm spots sit on the
  route.

## How it is built

- Platform roles: a `kit` meta on a platform (`stone`, `roof`, `hall`, ...) makes WorldSkin use `cap-<role>.png`,
  `fill-<role>.png`, `end-<role>.png`, `fringe-<role>.png` and `oneway-<role>.png`, and fall back to the plain pieces.
- Hand-placed decor: Marker2D nodes under `KitDecor` in `palace.tscn` name a `decor/<piece>.png`. When any decor
  resolves, the random landmarks, props and recess walls are skipped for that kit. Section walls sit on the back-wall
  layer (z -8), dressing on solid faces at z -3, props at z -2, and light pools are additive.
- Terrain pieces (`cap*`, `oneway*`, `fringe`) are generated raws re-sampled on their native pixel grid, cut to a whole
  pattern repeat and drawn at 2 art px per pixel, like the parallax layers. The end pilasters are drawn in code
  from the kit palette.

## Not done yet

The column, chandelier, fountain, deepstambh, banner and curtain pieces never came back from generation (Vertex 429s).
The existing kit pillar, lantern and lamp tower stand in for them. A future pass could add those pieces, foreground
silhouettes and hanging torans.
