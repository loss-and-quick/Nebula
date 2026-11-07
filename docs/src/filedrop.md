# Phone

The Phone panel sends files, links, text and your clipboard to your phone, and lists what the phone sends back. It runs on KDE Connect, so after one pairing the phone reconnects by itself whenever it is on the same Wi-Fi.

## Setup

Install KDE Connect on the PC and the KDE Connect app on your phone (Play Store, F-Droid or the App Store), then pair them once from the app. The panel's **Pair a phone** button opens KDE Connect on the PC if you have not paired yet.

    pacman -S kdeconnect sshfs

Bind the `quickshell:filedrop` shortcut to open the panel — see [Keybindings](keybindings.md).

## What the panel does

- **Send files**: drop them on the panel or click to choose. Screenshots and recordings also have a *Send to phone* button in the tools panel.
- **Send a link or text**: links open in the phone's browser, plain text lands on its clipboard.
- **Clipboard, Ring, Browse**: push the PC clipboard, make a lost phone ring, or open the phone's storage in your file manager (needs `sshfs`).
- **Recent**: files and text the phone sends appear here as they arrive; files go to your Downloads folder.

## Not nearby?

Open the KDE Connect app on the phone and check that both devices are on the same network. **Look again** asks KDE Connect to search immediately. Guest networks that isolate devices from each other block it.
