pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.utils
import qs.modules.settings
import qs.modules.components.custom

// Sleep / restart / shut down. Two-stage: the first click arms a red confirm,
// a second click within 4s runs it. Anything else collapses it.
//
// variant:
//   pill  — icon + label capsule
//   text  — bare label, dot separated
//   icons — icon-only circles
RowLayout {
    id: root

    property string variant: "pill"
    property string family: ""
    property int confirmIndex: -1
    property color tone: Colors.surfaceText
    property color plate: Colors.surfaceContainer
    property color plateHover: Colors.surfaceContainerHigh
    property real box: 42
    property real iconPx: 19
    property real tileW: 120
    property real tileH: 110
    property real tileRadius: 28

    readonly property string _family: root.family !== ""
        ? root.family
        : (SettingsConfig.general.defaultFont ?? "Rubik")

    readonly property bool _icons: root.variant === "icons"
    readonly property bool _text: root.variant === "text"
    readonly property bool _tile: root.variant === "tile"

    spacing: root._text ? 16 : 10

    readonly property var actions: [
        { icon: "bedtime",            label: "Sleep",     cmd: ["systemctl", "suspend"]  },
        { icon: "restart_alt",        label: "Restart",   cmd: ["systemctl", "reboot"]   },
        { icon: "power_settings_new", label: "Shut Down", cmd: ["systemctl", "poweroff"] }
    ]

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: root.confirmIndex = -1
    }

    function fire(index, cmd) {
        if (root.confirmIndex === index) {
            confirmTimer.stop()
            root.confirmIndex = -1
            Quickshell.execDetached(cmd)
        } else {
            root.confirmIndex = index
            confirmTimer.restart()
        }
    }

    Repeater {
        model: root.actions

        delegate: Item {
            id: entry
            required property int index
            required property var modelData

            readonly property bool confirming: root.confirmIndex === entry.index

            implicitWidth: root._tile ? root.tileW : root._icons ? root.box
                : (root._text ? textRow.implicitWidth : pillRow.implicitWidth + 30)
            implicitHeight: root._tile ? root.tileH : root._icons ? root.box
                : (root._text ? textRow.implicitHeight : 38)

            Rectangle {
                anchors.fill: parent
                radius: root._tile ? (entry.confirming ? height / 2 : root.tileRadius) : height / 2
                Behavior on radius { SpatialAnim { speed: "fast" } }
                visible: !root._text
                color: entry.confirming
                    ? Colors.error
                    : hover.hovered ? root.plateHover
                                    : root.plate
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            GridLayout {
                id: pillRow
                anchors.centerIn: parent
                visible: !root._text
                columns: root._tile ? 1 : 2
                columnSpacing: root._icons ? 0 : 8
                rowSpacing: 8

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: entry.modelData.icon
                    iconSize: root._tile ? 34 : root._icons ? root.iconPx : 17
                    customColor: entry.confirming ? Colors.errorText : root.tone
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root._icons
                    content: entry.confirming ? entry.modelData.label + "?" : entry.modelData.label
                    size: root._tile ? 15 : 13
                    weight: 600
                    family: root._family
                    customColor: entry.confirming ? Colors.errorText : root.tone
                }
            }

            RowLayout {
                id: textRow
                anchors.centerIn: parent
                visible: root._text
                spacing: 16

                CustomText {
                    visible: entry.index > 0
                    content: "·"
                    size: 14
                    weight: 500
                    customColor: Qt.alpha(root.tone, 0.45)
                }

                CustomText {
                    content: entry.confirming ? entry.modelData.label + "?" : entry.modelData.label
                    size: 13
                    weight: 600
                    family: root._family
                    customColor: entry.confirming
                        ? Colors.error
                        : hover.hovered ? root.tone
                                        : Qt.alpha(root.tone, 0.6)
                }
            }

            HoverHandler { id: hover }

            CustomMouseArea {
                radius: root._text ? 0 : root._tile ? root.tileRadius : entry.height / 2
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fire(entry.index, entry.modelData.cmd)
            }
        }
    }
}
