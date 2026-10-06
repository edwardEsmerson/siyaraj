# Siya's gameplay animations (C2)

Every player instance uses the approved 15-set library at
`assets/sprites/siya/cast_frames.tres`, including the original movement course,
forest/river/palace, weapon playground and boss arenas. No sprites were generated.
`scripts/player/player_visuals.gd` reads movement/combat after their physics ticks;
it never changes velocity, collision, health, ammunition or damage timing.

The collider stays 24×40. Art stays at scale 0.5, with the common 160×128 canvas
registered at feet (64,112). Mirroring also mirrors the asymmetric canvas offset.
Grey Body/FacingMarker/Name nodes remain hidden to preserve controller references
and inherited scene indices. Dash trails now sample the actual sprite and facing.

| Action | Presentation |
| --- | --- |
| idle / run | Grounded rest or horizontal movement; animation loops. |
| jump | Frames 1–2 by upward velocity, 3 near apex, 4 falling, 5 briefly after landing. |
| dash | Launch, then ride for the actual dash; brief brake pose afterward. Same ground/air art. |
| lash / air_lash | Frame 1 for windup, **frame 2 throughout the real ACTIVE damage window**. Ground recovery uses frame 3; air recovery holds frame 2. A jump switches to air art without starting a new swing. Facing follows the swing's locked direction. |
| skyshot | The weapon event shows release frame 2 immediately, then recovery frame 3 for the existing shot recovery. The firing controller already launches on input, so art adds no windup delay. |
| chakri_charge / release | Loop while charging; dash overrides the art while retaining charge. Actual release shows frame 2 then recovery frame 3. The existing instant radial hit is unchanged. |
| hurt / death | Hurt plays with the existing hit flash/protection blink. Death stays opaque, reaches the fallen pose and holds until the existing scene restart. |
| light_diya | Only a successful first E lighting in forest, side rooms, river or palace triggers it. Blocked/already saved diyas do not replay. |
| victory | Course `finished` or boss `died` queues a celebration when Siya is grounded and still. Movement or an attack can interrupt it. |
| talk / shocked | Available to future cutscenes through the API below; no new cutscene system is introduced. |

Damage/death and dash override other animations. Melee and weapons override cosmetic
poses. Cosmetic poses yield to player movement. Animation completion never unlocks
or prolongs a gameplay action. Death uses the existing restart delay; normal input
and dash buffering remain controller-owned.

Future cutscene callers can use:

```gdscript
player.get_node("Visuals").play_story(&"talk")
player.get_node("Visuals").play_story(&"shocked")
player.get_node("Visuals").clear_story()
```

`weapon_used(animation, duration)` is emitted only when the weapon actually fires.
The visuals connect to that signal on weapon-enabled players; the original
sparkler-only player works without it.

## Verification and review

`tests/player_visuals_check.gd` checks real physics, hit windows and weapon events,
ground/air dash and charge resumption, the collider/anchor, damage blink, death
hold, all three levels' diya interactions, level/boss victory, and story interruption.

The [review sheet](screenshots/siya/review-sheet.png) and the 20 individual PNGs
show real in-engine states. Closeups use camera zoom 4; the final forest image
uses the gameplay view. Approved sprites retain scale 0.5 in both cases.

```sh
godot --headless --path . --script res://tests/player_visuals_check.gd
xvfb-run -a godot --path . --script res://tools/player_shots.gd
python3 tools/player_sheet.py
```

The C2 branch leaves B0's dash changes to PR #24. Validation results for the
independent branch and the combined C2+B0 test copy are reported in the PR.
