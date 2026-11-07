# A Hyprland shell you put together yourself.

Nebula is a bar, panels, a dashboard, a launcher and desktop widgets, built with Quickshell. Most of it comes in more than one style, the bar goes on any edge, and the colours come from your wallpaper.

`bash <(curl -fsSL https://raw.githubusercontent.com/iamSt3el/Nebula/master/install.sh)`


Arch Linux, Hyprland 0.56 or newer with a Lua config. Free under GPL-3.0.

![The Nebula desktop: a bar along the top, a second bar of app icons down the left edge, and three widgets in the lower right, over a painted valley with a purple tree.](shots/hero.jpg)

An unedited screenshot of the desktop.

**1**

### Workspaces

Your workspaces. There are many styles to pick from.

**2**

### Window title

The focused app and workspace. Click it for window details.

**3**

### Music

Whatever is playing. Click for the music panel.

**4**

### Clock

Opens the calendar, with public holidays for your country.

**5**

### Status items

Weather, sound, brightness, network, Bluetooth, battery, notifications, power. Each opens its own panel.

**6**

### A second bar

Pinned apps on the left edge. Any edge can have its own bar.

**7**

### Desktop widgets

Music, a moon calendar and system load. You place and resize them in edit mode.

## The bar is the part you'll change most.

Items sit in blocks, and blocks sit on an edge. Every edge has its own shape, size and gaps, so a top bar and a side bar can look nothing alike.

Edges  
Top, bottom, left, right, or several at once

Items  
60, in five groups: core, launchers, stats, toggles and layout pieces like spacers and text

Shapes  
Pill, Merged, Stepped and Full to start from, then any gap and corner radius

Panels  
Attached, merged or floating, per edge or per block

Layouts  
Save a whole setup and switch with Super Alt \]

![The bar in the Pill shape: each block floats on its own.](shots/bar-pill.jpg)

Pill

![The bar in the Merged shape: blocks in a group join into one piece.](shots/bar-merged.jpg)

Merged

![The bar in the Stepped shape: blocks hang from the screen edge.](shots/bar-stepped.jpg)

Stepped

![The bar in the Full shape: one strip from side to side.](shots/bar-full.jpg)

Full

![The weather panel growing out of a full-width bar.](shots/panel-attached.jpg)

### Attached panel

Grows out of the bar.

![The weather panel joined to its block by a short neck.](shots/panel-merged.jpg)

### Merged panel

Joined to its block by a short neck.

![The weather panel floating below the bar.](shots/panel-floating.jpg)

### Floating panel

Floats below with a gap all round.

![Edit mode over a picture of Earth: the bars outlined, a toolbar along the bottom and buttons for the four screen edges.](shots/edit.jpg)

## Change it on the desktop, not in a file.

Press Super Shift E. You drag the real bar and the real widgets around, and every change can be undone.

Right-click a block to change its gaps or corners. Pick an edge to change its shape, size and panel style.

## Pick a style for each part.

![The Rail dashboard: clock and weather on the left, music, system stats and quick toggles beside them.](shots/dash-rail-sm.jpg)

### Dashboard, 7 styles

Rail, Poster, Stage, Planner, Ribbon, Instruments and a narrow Sidebar for side bars.

![The Dial music panel: the album cover inside a progress ring.](shots/music-dial-sm.jpg)

### Music panel, 3 styles

Poster, Dial and Beads.

![The Hearth launcher: a greeting, pinned apps and a grid of installed apps.](shots/launcher-hearth-sm.jpg)

### Launcher, 2 styles

Palette, a search field for apps, actions and windows. Hearth, a grid with your pinned apps.

## Leave out what you don't use.

Settings › Features lists 18 optional parts, like phone sync, clipboard history, books, the visualiser and smart lights. A part that's off doesn't load at all.

Your Hyprland config stays yours. The pages for displays, windows, keyboard and mouse, and shortcuts are off until you turn them on. Then they write either to their own file or to a marked block at the end of a file you pick, and leave the rest of it alone.

![The Features page in Nebula's settings, with switches for Phone, Clipboard history, Smart light, Weather and Calendar events.](shots/settings.jpg)

## Install

1.  1

    ### Run the installer

    It installs the packages and the `nebula` command. An existing `hyprland.lua` is kept as it is. Without one, you get a starter config.

    `bash <(curl -fsSL https://raw.githubusercontent.com/iamSt3el/Nebula/master/install.sh)`

    Copy

2.  2

    ### Run `nebula setup`

    Pick a wallpaper, your colours, the features you want and which apps should match. You can change all of it later.

Needs Arch Linux and Hyprland 0.56 or newer with `~/.config/hypr/hyprland.lua`. The older `hyprland.conf` format won't work, because Nebula talks to Hyprland in Lua.
