import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.utils

Scope {
    id: scope

    property bool loaded: false

    Connections {
        target: GlobalStates
        function onBooksOpenChanged() {
            if (GlobalStates.booksOpen) {
                unloadTimer.stop()
                scope.loaded = true
            } else {
                unloadTimer.restart()
            }
        }
    }

    Timer {
        id: unloadTimer
        interval: 60000
        onTriggered: if (!GlobalStates.booksOpen) scope.loaded = false
    }

    LazyLoader {
        id: booksLoader
        activeAsync: scope.loaded

        component: FloatingWindow {
            implicitWidth: Math.min(1440, (screen?.width ?? Quickshell.screens[0]?.width ?? 0) * 0.85)
            implicitHeight: Math.min(900, (screen?.height ?? Quickshell.screens[0]?.height ?? 0) * 0.85)
            title: "Reading"
            color: Colors.surface

            BooksContent {
                id: content
                focus: true
                onCloseRequested: GlobalStates.booksOpen = false
            }
        }
    }

    Binding {
        target: booksLoader.item
        property: "visible"
        value: GlobalStates.booksOpen
        restoreMode: Binding.RestoreNone
    }

    Connections {
        target: booksLoader.item
        function onVisibleChanged() {
            if (booksLoader.item && !booksLoader.item.visible)
                GlobalStates.booksOpen = false
        }
    }

    GlobalShortcut {
        name: "books"
        onPressed: GlobalStates.booksOpen = !GlobalStates.booksOpen
    }

    IpcHandler {
        target: "books"
        function open(): void { GlobalStates.booksOpen = true }
        function close(): void { GlobalStates.booksOpen = false }
        function toggle(): void { GlobalStates.booksOpen = !GlobalStates.booksOpen }
    }
}
