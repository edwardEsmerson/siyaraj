# Menus and UI theme

Screens: `scenes/main/title.tscn` (entry scene), `scenes/ui/pause_menu.tscn` (owned by
the `PlaytestNavigation` autoload), and the shared `scenes/ui/controls_panel.tscn` and
`scenes/ui/settings_panel.tscn`. `scenes/ui/theme_preview.tscn` shows every styled
control on one screen. Screenshots: `docs/screenshots/title-screen.png`,
`title-controls.png`, `pause-menu.png`.

## Using the theme

Set `theme = res://resources/ui/siyaraj_theme.tres` on the root Control of any new
screen; children inherit it. Plain `Panel`/`PanelContainer`, `Button`, `Label`,
`CheckBox` and `HSlider` are styled already. Type variations:

| variation | use |
| --- | --- |
| `TitleLabel` | the game logo (Yatra One, marigold with a pink drop) |
| `HeaderLabel` | panel headings |
| `KeyLabel` | key names and small marigold hints |

Add a `scripts/ui/diya_cursor.gd` TextureRect (texture `assets/ui/diya.png`) beside
a menu and point its `menu` at the container: a lit diya marks the focused button,
and hovering a button focuses it. Palette: aubergine `#1e0f26`, plum `#6e2853`, hot
pink `#d62876`, marigold `#ffb026`, turquoise `#3fd0c9`, cream `#fff1d6`.

Fonts are OFL (`assets/fonts/*-OFL.txt`): Yatra One for display text, Pixelify Sans
for everything else.

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
master volume to `user://settings.cfg` and applies them at startup.

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
