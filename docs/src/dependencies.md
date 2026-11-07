# Dependencies

The installer handles all of this. The lists here are for installing by hand, or for checking what a missing feature depends on.

## Packages

The authoritative lists live at the top of [`install.sh`](https://github.com/iamSt3el/Nebula/blob/master/install.sh). In short:

| Area        | Packages                                             |
|-------------|------------------------------------------------------|
| Shell       | `quickshell-git`, `hyprland`                         |
| Qt 6        | base, declarative, wayland, svg, multimedia          |
| Audio       | `pipewire`, `wireplumber`, `cava`                    |
| System      | `networkmanager`, `bluez`, `upower`, `brightnessctl` |
| Screenshots | `grimblast-git`, `swappy`                            |
| Recording   | `wf-recorder`                                        |
| Clipboard   | `wl-clipboard`, `cliphist`                           |
| Launcher    | `libqalculate`                                       |
| Theming     | `matugen-bin`, `ttf-material-symbols-variable-git`   |
| Build       | `gcc`, `cmake`, `extra-cmake-modules`                |

### Optional

| Package                | Needed for                                     |
|------------------------|------------------------------------------------|
| `ddcutil`              | Brightness control on external monitors        |
| `hyprlock`, `hypridle` | If you prefer them to the built-in lock screen |
| `qrencode`             | [Nebula Drop](filedrop.md)                     |

qrencode is not installed for you

The installer does not yet pull `qrencode` in, so Nebula Drop cannot draw its QR code until you install it yourself:

    pacman -S qrencode

## Python

Python lives outside the repo, at `~/.local/state/quickshell/.venv`, and is found through the `NEBULA_VENV` environment variable.

    uv venv --prompt nebula ~/.local/state/quickshell/.venv -p 3.12
    uv pip install materialyoucolor requests Pillow \
        --python ~/.local/state/quickshell/.venv/bin/python

| Package            | Used by                                       |
|--------------------|-----------------------------------------------|
| `materialyoucolor` | Palette extraction from the wallpaper         |
| `requests`         | Weather, holidays, Wallhaven search           |
| `Pillow`           | Image handling for wallpapers and colour work |
