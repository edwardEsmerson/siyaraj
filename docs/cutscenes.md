# Comic cutscenes and dialogue

`scenes/ui/comic_cutscene.tscn` is the shared static panel player and dialogue card.
Add it to a level or story scene, then call `play()` with a sequence of dictionaries:

```gdscript
$ComicCutscene.play([
	{
		"texture": "res://assets/cutscenes/intro-1.png",
		"speaker": "Raj",
		"text": "Diwali will be glorious this year!",
		"portrait": "res://assets/sprites/raj/portrait.png",
	},
])
```

Press the `ui_accept` action to advance each line. The `finished` signal fires when the
last line closes. For an in-world hint card, call `show_hint(speaker, text, portrait)`;
it leaves the level visible and closes on the same action. Portraits and panel textures
are optional `Texture2D` values or resource paths.

Panel art is generated with `python -m ab texture <name> "<scene brief>" --mode panel`.
Pass approved cast sprites with repeated `-r` flags. The image should not contain
lettering or speech bubbles; the game renders dialogue over the art.

## Campaign boss entries

Every campaign showdown opens with its approved pixel-art versus card: Siya against
Khara (forest), Dhoomketu (ghats), or Swaminathan (palace). The PNGs live in
`assets/cutscenes/boss-versus/`; approved sources, native pixels and generation prompts
live in `asset-builder/reviews/boss-versus-pixel-v2/`.

Use `{"texture": "res://assets/cutscenes/boss-versus/khara.png", "presentation": "versus", "text": ""}`
as the first introduction entry. This presentation fits the complete image with nearest
filtering, hides dialogue and featured-character overlays, and shows a small
`Enter / A: continue` prompt. The approved cards are 320x180 pixel art enlarged exactly
6x to 1920x1080. At the 960x540 game viewport, each source pixel occupies 3x3 pixels.

Finishing the forest or palace enters its showdown immediately; the ghats exit offers
Dhoomketu's fight. After the versus card, the forest and palace keep their existing
three dialogue panels. `subject` optionally places
existing character art above the dialogue over the panel's `texture` background.
Enter or gamepad A advances; held-key repeats are ignored. Arena processing stops
until the last panel closes, so neither Siya nor the boss can attack during dialogue.
Esc opens the regular pause menu.

The introduction is remembered for that encounter. Death, R, and checkpoint retries
reload the fight directly; launching the showdown afresh replays the introduction.
Terrain-only launches still bypass bosses, and the river retains its completion prompt.
Khara's victory leads to the river; Swaminathan's victory leads to the ending.

Khara uses the approved cast animations and registered gada hand positions.
Swaminathan now uses all eleven supplied body-state sprites. His attack origins,
telegraph glows and hurtbox follow the measured positions in that artwork.
