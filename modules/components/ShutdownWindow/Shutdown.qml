import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.components.custom
import qs.modules.components.Clipboard
import qs.modules.components.WallpaperSelector
import qs.modules.components.CustomContextMenu
import qs.modules.components.Osd

Scope {
    id: root

    Loader {
        id: loader
        active: GlobalStates.shutdownWindow
        sourceComponent: PanelWindow {
            id: panelWindow
            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            WlrLayershell.namespace: "quickshell:session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Normal
            color: "transparent"

            ShutdownContent {
                anchors.fill: parent
            }
        }
    }

    GlobalShortcut {
        name: "shutdown"
        onPressed: ServiceSession.toggleShutdown()
    }
}
