pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.modules.settings

Singleton {
    id: root

    readonly property bool shutdownOpen: GlobalStates.shutdownWindow

    readonly property var actions: [
        {
            id: "lock",
            label: "Lock",
            icon: "lock",
            key: "L",
            shape: "square",
            verb: "Locking",
            instant: true,
            command: ["loginctl", "lock-session"]
        },
        {
            id: "sleep",
            label: "Sleep",
            icon: "bedtime",
            key: "S",
            shape: "circle",
            verb: "Going to sleep",
            instant: true,
            command: ["systemctl", "suspend"]
        },
        {
            id: "logout",
            label: "Log out",
            icon: "logout",
            key: "E",
            shape: "arch",
            verb: "Logging out",
            instant: false,
            command: ["hyprctl", "dispatch", "exit"]
        },
        {
            id: "restart",
            label: "Restart",
            icon: "restart_alt",
            key: "R",
            shape: "cookie9",
            verb: "Restarting",
            instant: false,
            command: ["systemctl", "reboot"]
        },
        {
            id: "shutdown",
            label: "Shut down",
            icon: "power_settings_new",
            key: "P",
            shape: "clover4",
            verb: "Shutting down",
            instant: false,
            command: ["systemctl", "poweroff"]
        }
    ]

    function openShutdown(): void {
        GlobalStates.shutdownWindow = true;
    }

    function closeShutdown(): void {
        GlobalStates.shutdownWindow = false;
    }

    function toggleShutdown(): void {
        GlobalStates.shutdownWindow = !GlobalStates.shutdownWindow;
    }

    function lock(): void {
        root.closeShutdown();
        GlobalStates.lockRequested();
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }

    function sleep(): void {
        root.closeShutdown();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function logout(): void {
        root.closeShutdown();
        try {
            Hyprland.dispatch("exit");
        } catch (e) {
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"]);
        }
    }

    function restart(): void {
        root.closeShutdown();
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function shutdown(): void {
        root.closeShutdown();
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function firmware(): void {
        root.closeShutdown();
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }

    function run(action): void {
        const id = typeof action === "string" ? action : (action?.id ?? "");
        switch (id) {
        case "lock":
            root.lock();
            break;
        case "sleep":
            root.sleep();
            break;
        case "logout":
            root.logout();
            break;
        case "restart":
            root.restart();
            break;
        case "shutdown":
            root.shutdown();
            break;
        case "firmware":
            root.firmware();
            break;
        default:
            if (action?.command) {
                root.closeShutdown();
                Quickshell.execDetached(action.command);
            }
            break;
        }
    }

    IpcHandler {
        target: "session"
        function open(): void {
            root.openShutdown();
        }
        function close(): void {
            root.closeShutdown();
        }
        function toggle(): void {
            root.toggleShutdown();
        }
        function lock(): void {
            root.lock();
        }
        function sleep(): void {
            root.sleep();
        }
        function logout(): void {
            root.logout();
        }
        function restart(): void {
            root.restart();
        }
        function shutdown(): void {
            root.shutdown();
        }
        function firmware(): void {
            root.firmware();
        }
    }
}
