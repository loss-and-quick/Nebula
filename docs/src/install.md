# Install

Nebula targets Arch Linux and uses `pacman`. The installer pulls every dependency and sets up the shell, but leaves your Hyprland config alone.

## Automated install

Run this and answer the prompts:

    bash <(curl -fsSL https://raw.githubusercontent.com/iamSt3el/Nebula/master/install.sh)

Two flags are available:

| Flag | Effect                                 |
|------|----------------------------------------|
| `-f` | Skip confirmation prompts.             |
| `-s` | Skip the `pacman -Syu` system upgrade. |

### What the installer does

- Installs `yay` if it is not already present.
- Installs every pacman and AUR package Nebula needs.
- Clones Nebula to `~/.config/quickshell/nebula`, moving an older install from `~/.config/quickshell`.
- Creates the Python virtualenv at `~/.local/state/quickshell/.venv`.
- Fetches the Rubik font, builds the emoji index and compiles the WfRecorder plugin.
- Enables the pipewire, NetworkManager, bluetooth and upower services.
- Exports `NEBULA_VENV` and `QML_IMPORT_PATH` in your shell profile.

Your Hyprland config stays yours

If `~/.config/hypr/hyprland.lua` exists, the installer only adds `~/.config/hypr/nebula/` (autostart, layer rules, environment and the shell's shortcuts) and one `require` line per file. Without one it copies a starter config. The Hyprland pages in Settings stay off until you turn them on in Settings › Features, and they write only to a Nebula file or a marked block in a file you pick. Nebula needs Hyprland 0.56+ with a **Lua** config; `hyprland.conf` is not supported.

## Installing by hand

From a clone, three things have to happen: the plugin has to be built, the virtualenv has to exist, and two environment variables have to be set.

### 1. Build the recorder plugin

    bash plugins/WfRecorder/build.sh

This needs `gcc`, `cmake` and `extra-cmake-modules`.

### 2. Create the Python environment

Python lives outside the repo and is found through `NEBULA_VENV`:

    uv venv --prompt nebula ~/.local/state/quickshell/.venv -p 3.12
    uv pip install materialyoucolor requests Pillow \
        --python ~/.local/state/quickshell/.venv/bin/python

### 3. Export the variables and start the shell

    export QML_IMPORT_PATH="$HOME/.local/lib/qt6/qml"
    export NEBULA_VENV="$HOME/.local/state/quickshell/.venv"
    QSG_RENDER_LOOP=threaded quickshell

If the shell starts but pieces of it are missing, [Troubleshooting](troubleshooting.md) covers the usual causes.

## Updating

Nebula is a git clone, so pull in place:

    cd ~/.config/quickshell/nebula && git pull

Settings survive updates

Your configuration lives in `~/.config/nebula/settings.json`, outside the repo, so pulling will not overwrite it. Older installs kept it in `~/.cache/quickshell`; `nebula start` moves it across.
