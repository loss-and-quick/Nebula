# Launcher

One window does applications, calculation, shell commands, emoji and window switching. The first character you type decides which.

## The five modes

| Prefix | Mode | Example |
|----|----|----|
| *none* | Applications — fuzzy search, pinning, categories | `firefox` |
| `=` | Calculator and unit conversion | `= 100 usd to inr` |
| `>` | Shell command | `>systemctl suspend` |
| `:` | Emoji picker | `:fire` |
| `w` | Window switcher | `w term` |

Open it with the `quickshell:appLauncher` shortcut — see [Keybindings](keybindings.md) for how to bind it.

## Applications

With no prefix the launcher searches your installed applications with a fuzzy match, so `frfx` finds Firefox. Results can be pinned so they stay at the top, and browsed by category.

## Calculator

The `=` prefix hands the rest of the line to [libqalculate](https://qalculate.github.io), which means unit conversion and currency come along with arithmetic:

    = 100 usd to inr
    = 2^16
    = 45 kg to lb
    = 1920 / 1.618

## Shell command

`>` runs the rest of the line as a shell command.

It runs what you type

There is no confirmation step. A destructive command typed into this mode is executed the moment you press Enter, exactly as it would be in a terminal.

## Emoji

`:` searches the emoji index shipped in `assets/emoji.json` and copies the character you pick.

## Window switcher

`w` lists your open windows and matches on title, so `w term` jumps to a terminal wherever it is. This is the same set of windows the `quickshell:overview` screen shows, in a text-first form.
