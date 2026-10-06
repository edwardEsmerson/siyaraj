# Audio catalog and playback

Audio is ready on launch, through the campaign, in standalone boss arenas and in
the developer playgrounds. `AudioDirector` owns two music voices for crossfades,
one milestone voice and twelve short effect voices. The existing files in
`assets/Audio/` remain the source recordings.

## Music placement

| Scene | Recording | Source file | Entrance → background gain |
| --- | --- | --- | --- |
| Title and developer menu | Welcome to Persia Long | `extended_exploration.mp3` | −7 → −15 dB |
| Opening story | Diamond Rush: Title | `title_menu.mp3` | −2 → −10 dB |
| Opening forest | Diamond Rush: Title | `title_menu.mp3` | −2 → −10 dB |
| River, level two | Diamond Rush: Angkor Wat | `jungle_exploration.mp3` | −1 → −9 dB |
| Palace | Diamond Rush: Scotland | `stone_ruins_exploration.mp3` | −3 → −11 dB |
| Khara | Diamond Rush: Tibet | `mountain_exploration.mp3` | −3 → −10 dB |
| Dhoomketu | Diamond Rush: Scotland | `stone_ruins_exploration.mp3` | −2 → −9 dB |
| Swaminathan | Climbing the Throne Room | `palace_approach.mp3` | −4 → −14 dB |
| Ending | Welcome to Persia Long, with victory cue | `extended_exploration.mp3` | −7 → −15 dB |

Each entrance rises over 0.18 seconds, holds for 1.5 seconds, then eases down over
8 seconds. Music keeps looping at the quieter gain; loops do not repeat the loud
entrance. Scene transitions crossfade over 0.65 seconds. Checkpoint and forest-room
reloads preserve music position and gain. Boss retries replay their entrance.
Boss comics use exploration music; the fight track starts when the comic closes.

The five shorter recordings use prepared Ogg copies in `assets/Audio/music/`.
The originals contained 2.2–4.3 seconds of trailing silence; playback copies
remove that silence and use 8 ms boundary fades. Rebuild with
`python tools/prepare_music.py` (requires ffmpeg). Welcome to Persia uses its
original MP3. Track identities were recovered from the catalog before the semantic
filename rename; the two Persia titles are also in the MP3 tags.

## Diamond Rush milestone cues

| Event | Recording / file | Playback window |
| --- | --- | ---: |
| First lighting of a diya | Magic Circle / `magic_activation.mp3` | 2.05 s |
| New authored Robin hint | Riddle / `puzzle_clue.mp3` | 2.5 s |
| Entering a forest side room | What's in This Treasure Chest / `chest_anticipation.mp3` | 2.5 s |
| Clearing a side room or completing the bridge | Chest Open / `treasure_reveal.mp3` | 3.65 s |
| Placing a bridge board | Gear Mech Working / `mechanism_start.mp3` | 3 s |
| Level clear, boss victory and rescue ending | Win / `victory.mp3` | 6.45 s |
| Siya's death | Game Over / `defeat.mp3` | 1.5 s |

Cues fade over their last 0.3 seconds and lower music by another 7 dB while playing.
Death survives immediate retries without delaying gameplay. Only one melody plays
at a time: death has priority over victory, discovery, checkpoints and hints.
Menus clear gameplay cues. Repeated diya interactions and already-seen hints do
not replay their melodies.

## Original action effects

`assets/Audio/sfx/` contains twelve original synthesized effects: jump, rocket
dash, lash, skyshot, chakri charge/release, confirmed damage, enemy defeat,
enemy/boss attack tells, slam, curtain movement and menu confirmation. These
are 0.065–0.6 seconds long and trigger when actions actually succeed. They introduce
no additional third-party recordings. Rebuild with `python tools/generate_sfx.py`,
using Python's standard library.

Effects from distant actors attenuate and stop beyond 700 game units. Shared
cooldowns and a fixed voice pool bound overlapping sounds. Gameplay effects and
milestone cues pause; music and menu confirmation remain available in Settings.

## Mixing and verification

`default_bus_layout.tres` routes Music through a duck bus and SFX/UI through the
effects bus to Master. Master has a peak limiter. Title and pause Settings save
independent Master, Music and Effects sliders; older settings files still work.
Defaults are 80%, 80% and 90%. Per-track gains account for different source levels.

`tests/audio_check.gd` checks real entrances, fades, loop resources, checkpoint
continuity, action hooks, cue priority/ducking, pause behavior and saved settings.
`tools/pack_check.gd` checks every packed music/cue/effect. Physics/UI suites run
with `--silent-audio`; the dedicated audio suite runs the mixer and drains it
before quitting. This avoids Godot's [asynchronous playback shutdown leak](https://github.com/godotengine/godot/issues/76745)
without weakening the runner's script/resource-error checks. The title Quit button
and window-close handler likewise stop and drain playback before exiting.

For a rendered preview and an actual Master-bus recording, run:

```sh
xvfb-run -a godot --audio-driver Dummy --path . --script res://tools/audio_preview.gd
```

The recording is written to ignored `builds/audio/campaign-preview.wav`; the
Settings screenshot is `docs/screenshots/audio-settings.png`. See the recorded
[campaign audio preview](docs/audio/campaign-preview.ogg). The sample had no clipped
PCM samples and confirmed quieter music beds after the entrances. This is measured
playback validation, not a human listening review.

The requested Diamond Rush and Prince of Persia files remain third-party soundtrack
assets. The existing public-release licensing decision in `TODO.md` is separate
from this completed playback integration.
