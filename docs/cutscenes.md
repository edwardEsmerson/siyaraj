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

New Game plays `scenes/main/prologue.tscn` before entering the forest. The opening,
boss introductions and aftermath sequences live in `scripts/main/story_panels.gd`,
adapted from `siyaraj.refined.txt`. Direct developer level launches bypass the opening.

Every campaign showdown opens with its approved pixel-art versus card: Siya against
Khara, Dhoomketu, or Swaminathan. Gameplay PNGs live in
`assets/cutscenes/boss-versus/`; approved sources and generation prompts live in
`asset-builder/reviews/boss-versus-pixel-v2/`.

Set `CampaignFlow.versus_texture` to prepend the card to the current story dialogue.
The `versus` presentation fits the complete image with nearest filtering, hides
dialogue and both character overlays, and shows `Enter / A: continue`. Approved
cards are 320x180 pixel art enlarged exactly 6x to 1920x1080. Each source pixel
occupies 3x3 pixels at the 960x540 game viewport.

Finishing the forest or palace enters its showdown immediately. All three showdowns
select their dialogue using `CampaignFlow.story_key`. `subject` optionally places
existing character art above the dialogue over the panel's `texture` background.
`supporting_subject` shows a second character beside it for the abduction and reunion.
Enter or gamepad A advances; held-key repeats are ignored. Arena processing stops
until the last panel closes, so neither Siya nor the boss can attack during dialogue.
Esc opens the regular pause menu.

The introduction is remembered for that encounter. Death, R, and checkpoint retries
reload the fight directly; launching the showdown afresh replays the introduction.
Terrain-only launches still bypass bosses, and the river retains its completion prompt.
Defeating each boss plays its aftermath with arena processing stopped. Closing it
unlocks the victory prompt. Khara's aftermath leads to the river, Dhoomketu's to the
palace, and Swaminathan's reveals Robin's betrayal and Raj's rescue before the ending.
Developer snapshots return to level select after victory and omit aftermath sequences.

## Story adaptation and available art

Siya's parents make fireworks. A neighbour asks about Raj, and Siya witnesses
Swaminathan abducting him. Robin offers to guide her through the forest and ghats
to Lanka. Khara resents Siya and Raj breaking his toll gate; Dhoomketu resents their
exposure of his stolen fireworks; Swaminathan resents the family's refusal to obey
him. These grievances supply the requested personal motives, which the transcript
does not specify. The existing name Siya is retained; merge and TGC asides are omitted.

Robin remains useful during the journey. After Swaminathan falls, Robin admits that
he has always served him and deliberately guided Siya into the guards. He leaves,
and Siya reunites with Raj. There is no added Robin fight or redemption subplot.

The palace showdown displays Raj in a decorative hanging cage using his existing
sulk animation. Defeating Swaminathan opens its bars and plays Raj's freed animation.
The ending shows Siya and Raj together beneath her parents' fireworks.

Panels reuse the approved sprites and existing region backgrounds. The parents,
workshop and abduction action are conveyed through dialogue and narration because
dedicated artwork is unavailable. Dhoomketu's introduction shows Siya at the ghats;
his dedicated character art is still pending. The cage uses generated layered sprites
(`assets/sprites/raj-cage/`, built by `tools/raj_cage_art.py`; only its chain is still drawn in code)
and adds no collision to the arena. Enter or gamepad A advances each panel.

Khara uses the approved cast animations and registered gada hand positions.
Swaminathan now uses all eleven supplied body-state sprites. His attack origins,
telegraph glows and hurtbox follow the measured positions in that artwork.
