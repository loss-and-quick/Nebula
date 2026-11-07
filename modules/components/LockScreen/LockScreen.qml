pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.services

Scope {
    id: root

    property bool screenLocked: false
    property bool startAnimation: false
    onScreenLockedChanged: GlobalStates.sessionLocked = root.screenLocked

    function requestLock() {
        if (root.screenLocked)
            return
        root.startAnimation = false
        root.screenLocked = true
    }

    function isPrimary(screen) {
        const pm = SettingsConfig.general.primaryMonitor ?? ""
        if (pm !== "" && Quickshell.screens.some(s => s.name === pm))
            return !!screen && screen.name === pm
        return screen === Quickshell.screens[0]
    }

    LockContext {
        id: lockContext
        active: root.screenLocked

        onUnlocked: {
            timer.start()
            root.startAnimation = true
        }
    }

    Timer {
        id: timer
        interval: 1000
        onTriggered: {
            root.screenLocked = false
            root.startAnimation = false
        }
    }

    WlSessionLock {
        id: lock
        locked: root.screenLocked

        WlSessionLockSurface {
            id: lockSurface
            color: "black"

            Loader {
                id: contentLoader
                active: root.screenLocked
                asynchronous: true
                anchors.fill: parent

                sourceComponent: Item {
                    anchors.fill: parent

                    LockSurface {
                        width: parent.width
                        height: parent.height
                        context: lockContext
                        exiting: root.startAnimation
                        primary: root.isPrimary(lockSurface.screen)
                        shellScreen: lockSurface.screen
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onLockRequested() { root.requestLock() }
    }

    GlobalShortcut {
        name: "lock"
        description: "Lock the screen"

        onPressed: root.requestLock()
    }
}
