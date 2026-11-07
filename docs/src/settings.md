# Settings

Nebula is configured from a panel inside the shell rather than from a config file. There is no syntax to learn and no reload step.

## Opening settings

Bind the `quickshell:settingOpen` shortcut, or open Settings from the dashboard.

## Panels

| Panel         | Covers                                               |
|---------------|------------------------------------------------------|
| Theme         | Wallpaper, colour scheme variant, light or dark mode |
| Appearance    | Bar style, shapes, motion, fonts                     |
| Sound         | Output and input devices, volume behaviour           |
| Media         | Player preferences and the music visualiser          |
| Networking    | Wi-Fi and connection management                      |
| Bluetooth     | Pairing and connected devices                        |
| Notifications | Grouping, sounds, do not disturb                     |
| Weather       | Location and units                                   |
| Widgets       | Which widgets are on the canvas                      |
| Sleep         | Idle and lock behaviour                              |
| Storage       | The live disk treemap                                |
| About         | Version and system information                       |

## Where it is stored

All of it lands in one file:

    ~/.config/nebula/settings.json

Because it sits outside the repo, pulling an update never overwrites it. Backing up that one file backs up your whole configuration.

Edit it with the shell closed

The shell writes this file back as you change settings, so hand-edits made while it is running will be overwritten. Stop Quickshell first if you want to edit the JSON directly.

## Wallhaven

Wallpaper search needs a free [Wallhaven API key](https://wallhaven.cc/settings/account), set in the Theme panel. Local folders work without one.

## System drop-ins and administrator locks

On declarative systems (such as NixOS) or managed deployments, system-wide defaults and enforced policies can be placed in drop-in files under `$XDG_CONFIG_DIRS/nebula/*.json` (defaulting to `/etc/xdg/nebula/*.json`) and `/etc/nebula/config.json`. Drop-ins are merged beneath your personal `settings.json`, so your personal settings take precedence unless a key is locked.

Drop-ins can specify an admin lock list:

    {
      "locked": ["general.palette", "theme.themeApps"],
      "general": {
        "palette": "custom"
      }
    }

Locked keys are strictly read from the highest-precedence system drop-in and cannot be overwritten by user configuration or shell updates. Run `nebula settings-source <key>` to inspect the origin and lock status of any setting.
