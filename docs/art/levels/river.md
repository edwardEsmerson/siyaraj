# River level: art direction

Kit: `assets/world/river/titlematch/` (matches the title screen, `assets/backgrounds/title_skyline.png`).
Scene: `scenes/levels/river.tscn`, `WorldSkin.direction = "titlematch"`.

## Mood

Diwali evening on the Varanasi-style ghats. One long walk along the river from the last of the sunset to full
festival night, ending at the temple gate that leads up to the palace. Warm, festive and calm, never noisy:
the city is lit by thousands of small flames, and the player is always the brightest warm shape near the route.

## Palette

Locked to the title screen. Everything else is tinted toward it.

| role | colour | use |
| --- | --- | --- |
| aubergine | `#2a0f2b` - `#4a1a45` | outlines, foreground stone, deep water |
| plum | `#6b2a5e` - `#8a3a6e` | stone faces, mid buildings |
| hot pink | `#ff4f9a` | rim light on upper edges only (step lips, roof edges, ripples) |
| marigold | `#ffa52a` | flames, windows, garlands, the brightest accents |
| turquoise | `#3fc4c4` | sparse rangoli inlays, water highlights, festival cloth |
| sky | peach `#f6a77a` -> salmon `#e9767a` -> violet `#6a3a8a` -> indigo `#2a2050` | far layer only |

Rules: hot pink is a rim, never a fill. Marigold is light, so it belongs on lamps, windows and garlands, never on
large surfaces. Turquoise is for small things; one turquoise accent per screen region is enough.

## Colour script (left to right = sunset to night)

| # | section | x | sky | light | identity |
| --- | --- | --- | --- | --- | --- |
| 1 | Ferry landing | 0-2820 | golden peach sunset, low sun | warm, long | wooden piers on stilts, moored ferry boats, boatmen's umbrellas, nets and mooring posts |
| 2 | Stone fords | 2820-5600 | salmon dusk, kites | warm pink | open river: stepping stones, a mud sandbar with reeds and lotus, the half-sunk leaning temple in the water |
| 3 | Ghat courtyard | 5600-8100 | rose-magenta dusk | first aarti lamps | grand bathing ghat: big steps, palatial havelis, chhatri pavilions, bells, carved balconies |
| 4 | Broken bridge | 8100-9990 | violet twilight, first stars | lanterns | ruined stone arch bridge, hanging lanterns and rope, sky lanterns rising |
| 5 | Aqueduct | 9990-12560 | blue-violet blue hour, moon | cool with warm spots | tall stone aqueduct arches, water channels and spouts, step-well stone |
| 6 | Temple procession | 12560-14400 | indigo night, fireworks | festival glow | lamp towers, flags, torans, procession drums, the temple gate at the finish |

The far layer crossfades sunset -> twilight -> night across the course. The mid layer is a different
panel per section, so each stretch has its own skyline.

## Layers (back to front)

1. **Far** (`far.png`, scroll 0.15, opaque): sky + distant far-bank skyline + river reflection. Lightest values,
   lowest contrast.
2. **Mid** (`mid.png`, scroll 0.45, transparent): one skyline panel per section (ferry ghat, open river with
   the sunken temple, the grand ghat, the bridge ruin, the aqueduct, the temple complex). Hazed toward the sky so
   it sits behind the play layer.
3. **Landmarks** (`setpieces.png`, placed at `LandmarkSpots` markers, behind the actors): one or two signature
   pieces per section, standing on wide ground, never in front of a diya, door or the finish.
4. **Play layer**: platforms dressed by role (see below), hand-placed ornaments in `Decor/titlematch`.
5. **Water** (`water.png` + `water-top.png`): translucent river from just above the `RiverLine`; ghat steps
   and piles visibly sink into it; a bright ripple line marks the surface. Floating diyas and lotus pads ride it.
6. **Foreground** (hand-placed, in front of actors): only below the walking line (reeds, boat prows, lotus in
   the water) or at the very top of the screen (hanging garland strings, lantern lines). Never between the player
   and the route.

## Platform roles (`metadata/skin` on each platform)

| skin | where | top | face | ends |
| --- | --- | --- | --- | --- |
| `ghat` | banks, ghat steps, courts | stone lip with pink rim, lotus moulding | calm sandstone blocks | squared block corner |
| `dock` | piers, broken docks, the low recovery docks | plank deck | wooden pilings and braces, open between | post with rope |
| `rock` | stepping stones of the fords | worn rock with moss | rock | rounded rock |
| `bridge` | bridge deck and broken spans | flagstone deck with low parapet | bridge stone | broken jagged stone |
| `aqueduct` | channel steps and piers | channel lip with water | arch masonry | carved pier end |
| `temple` | procession court and temple steps | pale pink marble step with garland | carved plinth | moulded corner |
| `balcony` | one-way balconies | carved wooden jharokha deck | - | - |

Big masses never show one tile: fills are calm, the water covers the lower third, and roles change at platform
boundaries.

## Ornaments and density

- Every section gets: one hero landmark, 2-3 mid-size ornaments that frame a platform or mark a jump, and small
  props clustered in groups of 2-3 (never evenly sprinkled).
- Ornaments frame the route: posts and lamps at platform ends mark landing spots; overhead garlands span gaps
  the player must jump; bells hang where the route climbs.
- Keep 56 units clear around diyas, the finish, and each enemy's stand spot. No prop on a crate or a one-way top.
- Density rises with the colour script: sparse at the ferry, busiest at the procession.
- Grey edges are never visible: every platform end is finished with an end piece, a post, or an ornament.

## Landmarks

| section | landmark |
| --- | --- |
| Ferry | moored ferry boat with canopy, boatmen's umbrella cluster |
| Fords | half-sunk leaning temple in the river (decor, in the water) |
| Ghat | chhatri pavilion, brass aarti lamp stand |
| Bridge | broken bridge pier with lantern |
| Aqueduct | spout fountain / step-well gateway |
| Temple | deepstambh lamp tower, temple gate at the finish |

## How it is built

- Platform parts per skin (`cap-<skin>.png`, `fill-<skin>.png`, `end-<skin>.png`, `fringe-<skin>.png`,
  `oneway-<skin>.png`, `back-<skin>.png`) are drawn in the title screen's own pixel language (1 pixel = 1 game
  unit, saved at 2x): rim-lit stone lips, ghat stair faces, plank decks on open pilings, arcade undersides. The
  rock skin is generated (Nano Banana) with its diya/rangoli accents stripped so the fords stay calm.
- `far.png` is three generated sky panels crossfaded sunset -> twilight -> night (the last one tinted toward
  indigo); `mid.png` is one generated skyline panel per section, hazed toward that section's sky and lowered
  so it sits behind the play layer. Both are long, non-repeating strips sized to the course.
- Landmarks: `setpieces.png` holds one piece per row; `LandmarkSpots` markers in `river.tscn` place them.
- Ornaments, cover-crate fronts, bridge/aqueduct piers, rope strings across the gaps, boats and lotus on the
  water are hand-placed under `Decor/titlematch` (art in `decor/`).
