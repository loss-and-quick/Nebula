# Widget canvas

A full-screen canvas that you lay out by hand. Widgets are dragged into place and keep their position; everything is themed from the current palette.

## Opening the canvas

The widget screen is on the `quickshell:toolsWidget` shortcut. Bind it as described in [Keybindings](keybindings.md).

## Available widgets

| Group | Widgets |
|----|----|
| Time | Analog clocks (classic, minimal, shaped), digital clock, date cards in several styles, calendar |
| Weather | Forecast card, sun arc, moon phase |
| System | CPU and memory monitors, network graph, battery (bar, minimal and ring forms), temperature |
| Media | Media player controls, album art, CAVA audio spectrum |
| Notes | Sticky notes, task list, pomodoro timer |
| Feeds | RSS headlines |
| Profile | Profile card and tile |

## Arranging them

Widgets are placed by dragging. Which widgets are enabled, and their layout, is part of the settings stored in `~/.config/nebula/settings.json` — see [Settings](settings.md).

Widgets follow the wallpaper

Every widget takes its colours from the generated palette rather than carrying its own, so changing the wallpaper restyles the whole canvas. See [Theming other apps](theming.md).

## Weather and feeds need network access

The weather, RSS and holiday widgets fetch over the network using the Python environment. If they stay empty, confirm `NEBULA_VENV` is exported and that `requests` is installed in it — [Dependencies](dependencies.md) has the commands.
