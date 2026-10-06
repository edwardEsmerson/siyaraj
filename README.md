# Siyaraj

A Diwali-inspired 2D action platformer. Play as Siya and rescue Raj through
three regions and three boss fights, using sparkler lashes, skyshots,
charged chakris, and rocket dashes.

## Play in your browser

**Itch.io link: not published yet.** Replace this line with the real public
browser-playable URL before submission. Do not submit the GitHub URL to the bot.

Source: [edwardEsmerson/siyaraj](https://github.com/edwardEsmerson/siyaraj).
This release is silent. Checkpoints last for the current play session.
A browser refresh starts over. First-playthrough duration has not been measured.

## Team

Devil's Prasads, General Track.

- Ayaansh Solanki
- Atharva Desai
- Jonathan Robin
- Shourya Dixit
- Samhith Rao

## Controls

Click inside the game and choose New Game. Advance story panels with Enter or Space.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A / D or Left / Right arrows | Left stick or D-pad |
| Jump | Space | A / Cross |
| Rocket dash | Shift | RB / R1 |
| Sparkler lash | J | X / Square |
| Skyshot | L | Y / Triangle |
| Charged chakri | Hold K, then release when charged | Hold and release LB / L1 |
| Light diya / use door | E | B / Circle |
| Continue dialogue | Enter / Space | A / Cross |
| Pause / back | Escape | Menu / Start |
| Restart current level or fight | R | View / Select |

Press E beside a diya to save your position. Passing it does not save.
R restarts the level and clears its checkpoints. Dash works in the air once
per landing and provides brief protection against combat attacks. Watch the
HUD for available skyshots and the chakri cooldown.

## Setup and run

Use Godot 4.7.2 with the Compatibility renderer. No asset-generation tools or
paid assets are needed to run the game.

1. Clone this repository.
2. Open `project.godot` in Godot and wait for resource import.
3. Press F5, then choose New Game for the campaign.

From a terminal with Godot on PATH:

```sh
godot --path . --editor
godot --path .
```

The final merge hides the Playtest menu in all builds. Developers can open
individual level and arena scenes directly with F6. See [development notes](docs/development.md)
and [team workflow](docs/team_workflow.md) for developer tools.

## Browser build

Install the matching Godot 4.7.2 export templates through the editor.
The build helper copies the installed Web templates into ignored local storage.
Alternatively, extract `web_nothreads_release.zip` and `web_nothreads_debug.zip` from the official
4.7.2 template archive into `builds/templates/`.

On Windows PowerShell:

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
./tools/build_web.ps1
```

The helper imports the project, exports a release with threads off, creates
`builds/submission/siyaraj-web.zip`, and records source status and SHA256 hashes
in `builds/submission/build-report.txt`. It rejects stale files in `builds/web`.
Move a previous export aside before rebuilding.

On other platforms, place the Web templates in `builds/templates/`, create
`builds/web/`, and run:

```sh
godot --headless --path . --editor --import
godot --headless --path . --export-release Web builds/web/index.html
```

ZIP the files inside `builds/web/` so `index.html` is at the archive root.
Include `CREDITS.md` and `LICENSE` beside the export files.

To test locally, serve the files rather than opening the HTML directly:

```sh
python -m http.server 8000 --bind 127.0.0.1 --directory builds/web
```

Open http://127.0.0.1:8000 and test the full campaign. For upload settings and
page text, see [itch.io page copy](docs/itch_page.md). Final release checks are
in [the submission checklist](docs/submission_checklist.md).

## Credits, license, and AI

Team contributions use the [MIT license](LICENSE). Fonts retain their SIL
Open Font License notices. Read [CREDITS.md](CREDITS.md) for sources, licenses,
AI disclosure, and outstanding provenance confirmations. The per-file art
inventory is in [docs/asset_inventory.md](docs/asset_inventory.md).

The team reports Nano Banana for assets and AI assistance for code. Repository
metadata also records imagegen and gemini-3-pro-image, and commit trailers
credit Claude Opus 5.5. OpenAI Codex assisted with this release preparation.
Additional tools must be confirmed by the
team before publication. Previously tracked unlicensed audio is excluded from
this release and retained only in ignored local storage and earlier Git history.
