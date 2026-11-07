pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property string keymap: ""
    readonly property string code: {
        if (root.keymap === "")
            return "—"
        const match = root.keymap.match(/\(([^)]{2})\)/)
        return match ? match[1].toUpperCase() : root.keymap.slice(0, 2).toUpperCase()
    }
    property bool capsLockOn: false

    function switchNext() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? []
                    const main = keyboards.find(k => k.main) ?? keyboards[0]
                    if (main)
                        root.keymap = main.active_keymap ?? ""
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return
            const separator = event.data.indexOf(",")
            if (separator >= 0)
                root.keymap = event.data.slice(separator + 1)
        }
    }

    Process {
        running: true
        command: ["bash", "-c",
            "prev=x; while :; do s=0; " +
            "for f in /sys/class/leds/*::capslock/brightness; do " +
            "[ -r \"$f\" ] || continue; read -r v < \"$f\"; " +
            "[ \"$v\" != 0 ] && s=1; done; " +
            "if [ \"$s\" != \"$prev\" ]; then echo \"$s\"; prev=$s; fi; " +
            "sleep 0.4; done"]
        stdout: SplitParser {
            onRead: data => root.capsLockOn = data.trim() === "1"
        }
    }
}
