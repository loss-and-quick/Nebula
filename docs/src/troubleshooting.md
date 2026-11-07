# Troubleshooting

Most problems come from one of two environment variables not being set, because the features that depend on them fail quietly rather than loudly.

## Features fail silently, by design

Several parts of Nebula are opt-in and skip themselves when a dependency is absent, rather than showing an error. That keeps the shell usable when you have not set up a feature, but it does mean a missing package looks like a broken feature. When something does nothing at all, suspect a missing dependency before suspecting a bug.

## Screen recording does nothing

The recorder is a compiled Qt plugin, found through `QML_IMPORT_PATH`. Check that the variable is exported and that the plugin was actually built:

    echo $QML_IMPORT_PATH
    bash ~/.config/quickshell/nebula/plugins/WfRecorder/build.sh

It has to be set for the process that launches Quickshell, so put it in your Hyprland config rather than only in your shell profile — see [Hyprland setup](hyprland.md).

## Weather, colours or holidays stay empty

These all run through the Python virtualenv, located by `NEBULA_VENV`:

    echo $NEBULA_VENV
    "$NEBULA_VENV/bin/python" -c "import materialyoucolor, requests, PIL; print('ok')"

If the import fails, reinstall the packages as shown in [Dependencies](dependencies.md). If the variable is empty, add it to your Hyprland config.

## The Phone panel says "Not nearby"

The panel uses KDE Connect. Open the KDE Connect app on the phone, make sure both devices are on the same Wi-Fi, and press **Look again**. If no phone is paired, pair one from `kdeconnect-app` first.

## The greeter cannot read your wallpaper or palette

The greetd greeter runs as its own user, not as you, so it cannot read files under your home directory that are locked to your account. The usual blockers are `~/.cache` at mode `700`, `colors.json` at `600` and `~/.config/nebula`, where your settings live.

Grant the greeter user read access with an ACL:

    setfacl -m u:greeter:rx ~/.cache/quickshell
    setfacl -m u:greeter:r  ~/.cache/quickshell/colors.json
    setfacl -m u:greeter:rx ~/.config/nebula
    setfacl -d -m u:greeter:r ~/.config/nebula
    setfacl -m u:greeter:r  ~/.config/nebula/settings.json

A default ACL on its own is not enough

Setting only a default ACL on the directory leaves the mask at `---`, which denies the access you just granted. Set the entries explicitly as above. The greeter logs the exact paths it was denied, which is the fastest way to find any remaining one.

## Reading the shell’s own output

When something is genuinely broken rather than unconfigured, run Quickshell from a terminal so its messages are visible:

    QSG_RENDER_LOOP=threaded quickshell

## Still stuck

Open an issue on [GitHub](https://github.com/iamSt3el/Nebula/issues) with that terminal output, your Hyprland version, and which of the two environment variables are set.
