import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom

Scope {
    id: spot

    property bool on: false
    readonly property real dim: SettingsConfig.general?.spotlightDim ?? 0.55
    readonly property var active: Hyprland.activeToplevel?.lastIpcObject ?? null

    function toggle() { spot.on = !spot.on }

    GlobalShortcut {
        name: "spotlight"
        description: "Dim everything except the focused window"
        onPressed: spot.toggle()
    }

    IpcHandler {
        target: "spotlight"
        function toggle(): void { spot.toggle() }
        function on(): void { spot.on = true }
        function off(): void { spot.on = false }
    }

    Timer {
        interval: 300
        repeat: true
        running: spot.on
        triggeredOnStart: true
        onTriggered: Hyprland.refreshToplevels()
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            readonly property var mon: Hyprland.monitors.values.find(m => m.name === win.modelData.name) ?? null
            readonly property real monX: win.mon?.x ?? 0
            readonly property real monY: win.mon?.y ?? 0
            readonly property bool here: !!spot.active && (spot.active.monitor === win.mon?.id)
            readonly property bool fullscreenHere: !!win.mon?.activeWorkspace?.hasFullscreen
            property real fade: spot.on && !win.fullscreenHere ? 1 : 0

            screen: win.modelData
            visible: win.fade > 0.001
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:spotlight"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Behavior on fade { EffectsAnim { speed: "slow" } }

            Item {
                id: hole
                readonly property var at: spot.active?.at ?? [0, 0]
                readonly property var sz: spot.active?.size ?? [0, 0]
                x: win.here ? hole.at[0] - win.monX : win.width / 2
                y: win.here ? hole.at[1] - win.monY : win.height / 2
                width: win.here ? hole.sz[0] : 0
                height: win.here ? hole.sz[1] : 0
                Behavior on x { SpatialAnim {} }
                Behavior on y { SpatialAnim {} }
                Behavior on width { SpatialAnim {} }
                Behavior on height { SpatialAnim {} }
            }

            Shape {
                anchors.fill: parent
                opacity: win.fade
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: Qt.rgba(0, 0, 0, spot.dim)
                    fillRule: ShapePath.OddEvenFill
                    PathRectangle { x: 0; y: 0; width: win.width; height: win.height }
                    PathRectangle {
                        x: hole.x
                        y: hole.y
                        width: hole.width
                        height: hole.height
                        radius: 12
                    }
                }
            }

            Rectangle {
                x: hole.x - 2
                y: hole.y - 2
                width: hole.width + 4
                height: hole.height + 4
                radius: 14
                visible: hole.width > 0
                opacity: win.fade * 0.6
                color: "transparent"
                border.width: 2
                border.color: Colors.primary
            }
        }
    }
}
