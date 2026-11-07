# Hyprland setup

Nebula is only the shell. It never edits your Hyprland config, so the autostart line and keybinds below are yours to add — in a Lua config.

Lua config only

Nebula needs **Hyprland 0.56 or newer configured in Lua** (`~/.config/hypr/hyprland.lua`). The classic `hyprland.conf` format is not supported: the shell sends every window and workspace command to Hyprland as a Lua expression, and a `.conf` setup rejects them, so workspace switching, the overview and window actions stop working. `nebula doctor` tells you which one you have.

## Starting the shell

One line in your autostart. `nebula start` also launches the clipboard watcher if it is not running, and sets the environment the shell needs.

    hl.exec_cmd("nebula start")

The installer puts `nebula` in `/usr/local/bin`, so it is on Hyprland’s `PATH` at login.

## Keybinds

The shell registers named global shortcuts rather than grabbing keys itself, so you choose the keys. See [Keybindings](keybindings.md) for the full list of names.

    hl.bind("SUPER + CTRL + RETURN", hl.dsp.global("quickshell:appLauncher"))
    hl.bind("SUPER + L",             hl.dsp.global("quickshell:lock"), { locked = true })

## Border colours

Nebula writes `~/.config/hypr/lua/colors.lua` from your wallpaper and reloads Hyprland. Require it before the settings that use it:

    local colors = require("lua.colors")
    hl.config({ general = { col = {
        active_border   = colors.active_border,
        inactive_border = colors.inactive_border,
    } } })

## A ready-made set

A complete Lua config is committed in [`config/hypr/`](https://github.com/iamSt3el/Nebula/tree/master/config/hypr): `hyprland.lua` plus `lua/` modules for autostart, keybinds, rules and monitors. Copy the parts you want; `monitor.lua` starts every screen at its preferred mode.
