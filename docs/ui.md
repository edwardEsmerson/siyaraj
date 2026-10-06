# Menus and UI theme

Screens: `scenes/main/title.tscn` (entry scene), `scenes/ui/pause_menu.tscn` (owned by
the `PlaytestNavigation` autoload), and the shared `scenes/ui/controls_panel.tscn` and
`scenes/ui/settings_panel.tscn`. `scenes/ui/theme_preview.tscn` shows every styled
control on one screen. Screenshots: `docs/screenshots/title-screen.png`,
`title-controls.png`, `pause-menu.png`.

## Using the theme

The project-wide theme is `res://resources/ui/siyaraj_theme.tres`, including world
labels beneath Node2D scenes. Set it explicitly on reusable screen roots too.
Plain `Panel`/`PanelContainer`, `Button`, `Label`,
`CheckBox` and `HSlider` are styled already. Type variations:

| variation | use |
| --- | --- |
| `TitleLabel` | the game logo (Yatra One, marigold with a pink drop) |
| `HeaderLabel` | panel headings |
| `KeyLabel` | key names and small marigold hints |
| `HUDTitle` | compact marigold gameplay headings |
| `WorldSign` | gold route headings and traversal instructions |
| `WorldPrompt` | cream doorway and checkpoint prompts |
| `DeathLabel` | framed respawn message |

Add a `scripts/ui/diya_cursor.gd` TextureRect (texture `assets/ui/diya.png`) beside
a menu and point its `menu` at the container: a lit diya marks the focused button,
and hovering a button focuses it. Palette: aubergine `#1e0f26`, plum `#6e2853`, hot
pink `#d62876`, marigold `#ffb026`, turquoise `#3fd0c9`, cream `#fff1d6`.

Yatra One is the shared display and body font, licensed under OFL
(`assets/fonts/YatraOne-OFL.txt`). Body text is normally 16px; dense HUD and
controls rows use 13–14px. Text controls use linear filtering for antialiased
glyphs while world art retains nearest filtering. Use plum text without an
outline on cream speech bubbles, and cream/gold text with plum outlines over art.

Use escaped `\n` in scene text instead of literal multiline strings: CRLF inside
a quoted scene string can produce extra blank lines when Godot wraps it.

## Victory and completion

`scenes/ui/result_screen.tscn` shares the menu's panel, divider, diya, and button
art. `present(title, detail, destination)` sets its content and focuses Continue.
Its `continued`, `replayed`, and `menu_requested` signals are connected by the
level or boss controller. Campaign and developer boss arenas both use it.
Continue advances the campaign or returns a snapshot to the developer menu;
Play Again restarts the current level/snapshot; Menu returns to the title.
Enter/A selects the focused button, R replays, and Esc opens the pause menu.

Layout and button navigation are covered by `tests/typography_check.gd`.
Rendered examples are in `docs/screenshots/typography/`, including all three
level and boss HUDs, Root Hollow, dialogue, and the completion/victory cards.

## Controller controls

The shared Controls panel reads keyboard and joypad events from the InputMap and
shows Xbox / PlayStation button names. Bindings accept any connected controller.
Menus use D-pad or left stick navigation, A/Cross to confirm, and Menu/Start to
pause or go back. B/Circle only interacts in gameplay, so lighting a diya never
opens the pause menu. Keyboard bindings remain available.

| Action | Controller |
| --- | --- |
| Move | Left stick or D-pad |
| Jump / confirm / continue | A / Cross |
| Rocket dash | RB / R1 |
| Sparkler lash | X / Square |
| Skyshot | Y / Triangle |
| Chakri | Hold and release LB / L1 |
| Light diya / use door | B / Circle |
| Pause / back | Menu / Start |
| Restart level or snapshot | View / Select |
| Cycle scenery (developer tool) | Right stick click |

The left stick has a 0.2 deadzone. Controller checks in `tests/menus_check.gd`
cover axis direction and drift, menu navigation, confirm, pause/resume and the
interaction/pause separation. Physical controller feel still needs a playtest.
The rendered [Controls panel](screenshots/controls-gamepad.png) fits the 960 x 540
viewport on both the title and pause menus.

## Settings

`GameSettings` (autoload, `scripts/main/game_settings.gd`) saves fullscreen and
Master, Music and Effects volumes to `user://settings.cfg` and applies them at startup.
Music and menu feedback remain available while gameplay is paused. See
[`AUDIO_CATALOG.md`](../AUDIO_CATALOG.md) for track placement and mixing.

## Making UI art

UI art is drawn at 1 texel = 1 game unit (the parallax layers' density), so it is
used at scale 1. From `asset-builder/`:

```sh
~/ml/bin/python -m ab ui panel "<brief>" --px 72 --corner 18      # 9-slice frame
~/ml/bin/python -m ab ui diya "<brief>" --kind icon --px 16       # icon
```

Frames are mirrored to four identical corners and rebuilt as a 9-slice
(`NN-nine.png`); use it in a StyleBoxTexture with `texture_margin` from
`margins.json` and axis stretch `TILE_FIT`. The title skyline came from
`python -m ab texture title-skyline ... --mode cutout --aspect 16:9 --key blue`,
cropped to 1920x1080 and halved to 960x540.
