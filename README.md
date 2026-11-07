<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo/nebula-dark.svg">
  <img src="assets/logo/nebula-light.svg" alt="Nebula logo" width="96">
</picture>

# Nebula

A personal, hardened and architecturally refactored fork of [Nebula](https://github.com/iamSt3el/Nebula): a Material You desktop shell for Hyprland, built with [Quickshell](https://quickshell.org/).

[Features](#features) · [Architecture](#architecture) · [Install](#install) · [Documentation](#documentation) · [Command line](#command-line)

<img src="assets/showcase/desktop.jpg" alt="Nebula desktop on Hyprland" width="100%">

</div>

## Features

- Wallpaper-derived Material You colours for the shell and other applications.
- An editable bar and dock, dashboard and desktop widgets.
- A launcher for apps, calculations, shell commands, emoji and windows.
- A lock screen with multiple layouts and an optional greetd greeter.
- Notifications, clipboard history, screenshots, recording, wallpaper browsing and KDE Connect integration.

## Architecture

- Hardware-accelerated GPU vector icons using `QtQuick.Shapes` and `CurveRenderer`.
- Native Qt 6 `QtQuick.Effects`, without Qt5Compat effects.
- Qt Quick Controls templates including `T.Control`, `T.ToolSeparator` and `M3ItemDelegate`.
- Transactional, event-driven configuration and services, avoiding timer and inotify race workarounds.
- Multithreaded C++ `SystemStats` worker for system statistics without blocking the main thread.
- Immediate Wayland `ext-session-lock-v1` lock requests, without pre-lock screenshot delays.
- Modern mdBook documentation and a native Nix flake.

## Install

Run the native flake on Nix:

```bash
nix run github:loss-and-quick/Nebula
```

On Arch Linux, the installer sets up dependencies, plugins and Hyprland integration:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/loss-and-quick/Nebula/master/install.sh)
```

Nebula requires Hyprland 0.56 or newer with a Lua configuration (`~/.config/hypr/hyprland.lua`); the classic `hyprland.conf` format is not supported. After installation, log in again and run `nebula setup` to configure your wallpaper, colours and app theming.

## Documentation

The [mdBook documentation](docs/src/SUMMARY.md) covers installation, configuration and the shell's features. To build it locally, run `mdbook build docs`.

## Command line

```bash
nebula start                          # or stop, restart
nebula setup                          # wallpaper, colours and apps
nebula wallpaper set ~/wallpaper/forest.png
nebula scheme set --mode light        # or --variant vibrant
nebula apps                           # which apps follow the palette
nebula settings-source                # check settings origin and admin locks
nebula doctor                         # check dependencies
nebula uninstall                      # --purge also deletes settings
```

Run `nebula help` for the complete command list. The palette is written to `~/.cache/quickshell/colors.json`; `nebula setup` or `nebula apps` selects applications to theme. For a fixed external palette, set the scheme variant to `custom` and place colours in `~/.config/nebula/colors.json`.

## Credits

Based on [Nebula](https://github.com/iamSt3el/Nebula). Thanks to [end_4](https://github.com/end-4) for inspiration, Quickshell patterns and [rounded-polygon-qmljs](https://github.com/end-4/rounded-polygon-qmljs), [soramane](https://github.com/soramanew) for design inspiration, and [outfoxxed](https://outfoxxed.me/) for Quickshell.

## License

[GNU GPL v3.0](LICENSE). The material shape geometry in `plugins/Nebula/shapes.cpp` is a C++ port of rounded-polygon-qmljs by end_4, used under its original [Apache License 2.0](modules/MaterialShapes/LICENSE).
