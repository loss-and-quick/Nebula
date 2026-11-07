# Theming other apps

Nebula extracts a Material You palette from your wallpaper and writes it to disk. Other applications can pick up the same colours through their own templates.

## The palette file

The shell always writes its own palette here, whatever else is configured:

    ~/.cache/quickshell/colors.json

Colours are extracted by `nebula scheme` using the Python `materialyoucolor` library, with results cached so repeat wallpapers are instant. Anything that can read JSON — an editor plugin, your own script — can read this file directly and needs no template at all.

## Custom static palette

If you prefer an external theming system (such as NixOS Stylix, pywal, or a base16 scheme) to drive the shell's colors instead of deriving them from the wallpaper, you can provide a static palette file at:

    ~/.config/nebula/colors.json

Activate it by selecting **Custom** under Colour scheme in Settings, or via the CLI with `nebula scheme set --variant custom` (or `nebula palette set <file>`). When active, Nebula skips Material You generation entirely on wallpaper changes, reads colors directly from this file, and still renders your app templates.

## Rendering into other apps

Nebula can also render the palette into other applications’ config files. Each target is opt-in and is silently skipped unless *both* of these already exist:

1.  A matugen-style template at `~/.config/matugen/templates/<name>`
2.  The parent directory of the output file

Nebula ships none of these configs and will not create them

If you have never written the template, nothing happens and no error is raised. That is deliberate — the shell does not generate config files for applications you may not use.

### Templates and where each one lands

| Template | Written to |
|----|----|
| `btop.theme` | `~/.config/btop/themes/matugen.theme` |
| `kitty-colors.conf` | `~/.config/kitty/colors.conf` |
| `gtk-colors.css` | `~/.config/gtk-3.0/gtk.css` |
| `gtk4-colors.css` | `~/.config/gtk-4.0/gtk.css` |
| `qt-colors.conf` | `~/.config/qt5ct` and `qt6ct/colors/matugen.conf` |
| `colors.css` | `~/.config/waybar/colors.css`, `nwg-dock-hyprland/colors.css` |
| `hyprland-colors.lua` | `~/.config/hypr/lua/colors.lua`, then the border colours are set live with `hyprctl eval` |
| `tmux-colors.conf` | `~/.config/tmux/colors.conf` |
| `starship.toml` | `~/.config/starship.toml` |
| `pywalfox-colors.json` | `~/.cache/wal/colors.json` |

## Including the generated file

Writing the file is only half of it — the application has to include it from its own config:

    # kitty.conf
    include colors.conf

    /* waybar style.css */
    @import "colors.css";

    -- hyprland.lua
    local colors = require("lua.colors")

## The one that ships

Every template in the table ships in [`config/matugen/templates/`](https://github.com/iamSt3el/Nebula/tree/master/config/matugen/templates) and the installer copies them into place. Terminal colours (kitty, tmux, starship, btop) use a harmonized ANSI palette that stays readable in light and dark mode.
