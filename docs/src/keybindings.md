# Keybindings

Nebula registers named global shortcuts instead of grabbing key combinations. You bind whatever keys you like to the names below.

## How binding works

Every shortcut is exposed as `quickshell:<name>`. Dispatch to it with Hyprland’s `global` dispatcher:

    hl.bind("SUPER + V", hl.dsp.global("quickshell:clipboard"))

## The shortcuts

| Name                 | Opens                         |
|----------------------|-------------------------------|
| `appLauncher`        | App launcher                  |
| `overview`           | Workspace overview            |
| `clipboard`          | Clipboard history             |
| `wallpaperLauncher`  | Wallpaper selector            |
| `toolsWidget`        | Tools and widget screen       |
| `filedrop`           | Phone panel (KDE Connect)     |
| `settingOpen`        | Settings                      |
| `cheatsheet`         | Keybinding cheat sheet        |
| `lock`               | Lock screen                   |
| `shutdown`           | Session menu                  |
| `brightnessIncrease` | Brightness OSD, one step up   |
| `brightnessDecrease` | Brightness OSD, one step down |

## Binds that fire on the lock screen

A normal bind is inert once the session is locked. Pass `locked = true` so it still fires — this is what makes `quickshell:lock` itself usable, and it matters for brightness too:

    hl.bind("SUPER + L", hl.dsp.global("quickshell:lock"), { locked = true })

Not everything is a shortcut

The dashboard, the notification shade and the weather panel open from the bar rather than from a keybind, so they have no name in the table above.

## Cheat sheet

The shell ships a cheat sheet of your own binds, on `quickshell:cheatsheet`. Bind it to something you will remember.
