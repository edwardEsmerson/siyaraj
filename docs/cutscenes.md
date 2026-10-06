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

Finishing the forest or palace enters its showdown immediately. Each showdown's
`CampaignFlow.introduction` contains three comic panels. `subject` optionally places
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
