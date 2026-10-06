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
