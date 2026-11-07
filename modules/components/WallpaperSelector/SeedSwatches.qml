import QtQuick
import Quickshell.Widgets
import qs.modules.services
import qs.modules.utils
import qs.modules.components.custom

Row {
    id: root

    property string path: ""
    property int disc: 30
    property color ring: Colors.primary

    readonly property string key: root.path ? ServiceWallpaper._seedKey(root.path) : ""
    readonly property var info: root.key ? ServiceWallpaper.seedInfo[root.key] || null : null
    readonly property var seeds: root.info ? root.info.seeds : []

    spacing: 12
    onKeyChanged: ServiceWallpaper.requestSeeds(root.path)
    Component.onCompleted: ServiceWallpaper.requestSeeds(root.path)

    Repeater {
        model: root.seeds

        Item {
            id: swatch

            required property var modelData
            required property int index
            readonly property bool chosen: root.info !== null && root.info.chosen === swatch.index

            width: root.disc
            height: root.disc

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: root.ring
                opacity: swatch.chosen ? 1 : 0
                Behavior on opacity { EffectsAnim { speed: "fast" } }
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: swatch.modelData.primary

                Rectangle {
                    y: parent.height / 2
                    width: parent.width / 2
                    height: parent.height / 2
                    color: swatch.modelData.secondaryContainer
                }

                Rectangle {
                    x: parent.width / 2
                    y: parent.height / 2
                    width: parent.width / 2
                    height: parent.height / 2
                    color: swatch.modelData.tertiary
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ServiceWallpaper.chooseSeed(root.path, swatch.index)
            }
        }
    }
}
