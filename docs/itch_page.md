# Itch.io page copy

Replace the missing public game URL in README.md after creating the page.
Copy the player-facing sections below into the itch.io description and
instructions. Publish the final credits from CREDITS.md in full on the page.

## Title

Siyaraj

## Short description

Rescue Raj with sparkler lashes and rocket dashes through a forest, river ghats,
and palace in this Diwali-inspired action platformer.

## Description

Swaminathan has taken Raj. Play as Siya, a firework maker's daughter, and
follow Robin through the forest and river ghats to the palace.

Jump between platforms, dash through attacks, and fight with a sparkler lash,
skyshots, and a charged chakri. Light diyas to save your progress within each
level. Defeat Khara, Dhoomketu, and Swaminathan to reach the ending.

A game by Devil's Prasads for the General Track.

Team: Ayaansh Solanki, Atharva Desai, Jonathan Robin, Shourya Dixit, and Samhith Rao.

Source code: https://github.com/edwardEsmerson/siyaraj

Campaign music and gameplay sound effects are included. Resolve the supplied soundtrack licensing before publishing. The developer playtest
menu is hidden in the release build. Browser reloads start the game again;
diya checkpoints are for the current session.

## How to play

Click inside the game, then select New Game. Press Enter or Space to advance
the story. Use the fullscreen button if the game feels too small.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or Left / Right arrows | Left stick or D-pad |
| Jump | Space | A / Cross |
| Rocket dash | Shift | RB / R1 |
| Sparkler lash | J | X / Square |
| Skyshot | L | Y / Triangle |
| Charged chakri | Hold K, then release after charging | Hold and release LB / L1 |
| Light diya / use door | E | B / Circle |
| Continue dialogue | Enter / Space | A / Cross |
| Pause / back | Escape | Menu / Start |
| Restart current level or fight | R | View / Select |

### Hints

- Press E beside a diya to activate its checkpoint. Walking past it does not save.
- Rocket dash works on the ground and in the air. You regain your air dash on landing.
- Dash grants brief invulnerability against combat attacks. Use it to pass through a telegraphed strike.
- J works in the air too. Jump to reach flying enemies.
- Skyshots are limited. Watch the HUD before firing.
- Hold K until the chakri charge is full, then release. It has a cooldown.
- Watch boss telegraphs and counterattack during recovery. Stand in the teal lanes during Swaminathan's Fury.
- R restarts the level and clears its checkpoint progress. Use it deliberately.

## Credits and AI disclosure

Paste the full contents of the root CREDITS.md here. Do not publish this
instruction as the credits. Confirm the outstanding tool and asset provenance
details first, then keep the itch.io credits and repository credits identical.

## Upload settings

1. Create a project with title Siyaraj and kind of project HTML.
2. Upload `builds/submission/siyaraj-web.zip` and select "This file will be played in the browser".
3. Set the viewport to 960 by 540 and enable the fullscreen button.
4. Use click-to-play. Leave SharedArrayBuffer support off because the Web preset uses no threads.
5. Use no payment requirement. Paste the description, instructions, and complete credits.
6. Add current screenshots from the actual final browser build. Existing screenshots in `docs/screenshots/` are references and may show earlier versions.
7. Set visibility to Public once the page and build have been tested.
8. Replace the missing game link in README.md with the public itch.io URL.
9. Open that URL while signed out, play the complete campaign, and submit that exact URL through the official Discord bot.

Itch.io requires a ZIP containing an entry point named `index.html`:
https://itch.io/docs/creators/html5

Godot Web export and thread guidance:
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
