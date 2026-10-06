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
