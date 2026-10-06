# Credits

## Team

Devil's Prasads, General Track.

- Ayaansh Solanki
- Atharva Desai
- Jonathan Robin
- Shourya Dixit
- Samhith Rao

These are the names supplied by the team. Registration and individual roles
must be checked against Indieconnect before submission.

## Fonts and engine

| Asset | Author and source | License | Files |
| --- | --- | --- | --- |
| Yatra One | The Yatra Project Authors, [Google Fonts source](https://github.com/google/fonts/tree/main/ofl/yatraone) | SIL Open Font License 1.1 | `assets/fonts/YatraOne-Regular.ttf`, `assets/fonts/YatraOne-OFL.txt` |
| Pixelify Sans | The Pixelify Sans Project Authors, [project source](https://github.com/eifetx/Pixelify-Sans) | SIL Open Font License 1.1 | `assets/fonts/PixelifySans-Variable.ttf`, `assets/fonts/PixelifySans-OFL.txt` |
| Godot Engine | [Godot contributors](https://godotengine.org/license/) | MIT; bundled third-party libraries retain their own licenses | Engine runtime in the exported build |

The font license notices ship with the browser pack. Godot's engine and
third-party notices are available at the linked engine license page.

## Art and AI disclosure

The team reports using Nano Banana to generate assets and AI tools to assist
with code. Git commit trailers credit Claude Opus 5.5 for code assistance.
This release preparation also used OpenAI Codex for documentation, export
configuration, packaging, and verification.

Repository generation metadata additionally records `imagegen` and
`gemini-3-pro-image`. They are disclosed here rather than omitted from the
team's reported tool list. Teammates should confirm whether any additional
code, text, image, sound, or 3D tools were used beyond these recorded tools.

| Asset group | Source and provenance | License or status |
| --- | --- | --- |
| Character sprites and animations in `assets/sprites/` | [Team generation manifest](https://github.com/edwardEsmerson/siyaraj/blob/main/asset-builder/cast_manifest.json), source sheets and prompts in `asset-builder/sprites/`; Nano Banana and recorded image generators | AI-generated team assets; the project MIT license applies to the team's licensable contributions. Generator terms still apply. |
| Forest, river, and palace textures in `assets/world/` | [Team texture sources](https://github.com/edwardEsmerson/siyaraj/tree/main/asset-builder/textures), [world art notes](https://github.com/edwardEsmerson/siyaraj/tree/main/docs/art/levels); team reports Nano Banana | AI-generated team assets; same licensing scope as above |
| Backgrounds and UI textures in `assets/backgrounds/` and `assets/ui/` | [Team art tooling](https://github.com/edwardEsmerson/siyaraj/tree/main/asset-builder), [UI generation notes](https://github.com/edwardEsmerson/siyaraj/blob/main/docs/ui.md) | AI-generated team assets; same licensing scope as above |
| `icon.svg` | Godot project icon included by the engine's starter project | Godot MIT license |

See [the file inventory](docs/asset_inventory.md) for every retained asset.
Confirm the provenance of each group and disclose any additional generators
before publishing. AI output is not represented as CC0 or CC BY without a
separate grant. The team must describe its own design and direction in the
submission; AI assistance alone does not establish that requirement.

## Audio excluded from this release

This build is silent. The previous `assets/Audio/` collection was identified
in `TODO.md` as music from Diamond Rush and Prince of Persia: The Forgotten
Sands, with no redistribution license supplied. It has been moved to ignored
local build storage and is excluded from exports and the working source tree.
It is not licensed by this project's MIT license. Earlier Git history still
contains those files; no history has been rewritten.

No paid third-party asset is intentionally included in the release. This is
an inventory based on repository evidence and the team's report, not a claim
that the organisers have verified eligibility.
