import qs.modules.components.Bar
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.components.custom

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    readonly property int bars: BarLayout.opt(root.itemId, "bars") ?? 5
    readonly property real maxHeight: BarLayout.opt(root.itemId, "height") ?? 16
    readonly property string role: BarLayout.opt(root.itemId, "role") ?? "primary"
    readonly property bool active: ServiceMusic.isPlaying

    implicitWidth: root.bars * 3 + (root.bars - 1) * 2 + 8
    implicitHeight: root.maxHeight

    Row {
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.bars

            delegate: Rectangle {
                id: bar
                required property int index

                readonly property real restHeight: 3
                readonly property real peak: root.maxHeight * (0.35 + 0.65 * Math.abs(Math.sin((bar.index + 1) * 1.7)))

                width: 3
                height: bar.restHeight
                radius: 1.5
                color: BarLayout.roleColor(root.role)
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation {
                    running: root.active
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        bar.height = bar.restHeight

                    NumberAnimation {
                        target: bar
                        property: "height"
                        to: bar.peak
                        duration: 320 + bar.index * 70
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: bar
                        property: "height"
                        to: bar.restHeight + root.maxHeight * 0.12
                        duration: 280 + bar.index * 55
                        easing.type: Easing.InOutSine
                    }
                }

                Behavior on color {
                    EffectsColorAnim {}
                }
            }
        }
    }
}
