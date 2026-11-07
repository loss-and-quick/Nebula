import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.components.custom

ColumnLayout {
    id: root

    property string mode: "windows"
    property var sides: ["top", "right", "bottom", "left"]
    property var values: ({})
    property int maxValue: 20
    property var maxFor: ({})
    property int topRadius: 20
    property int bottomRadius: 20
    property string barSide: "top"
    property string linkLabel: "Same on all sides"

    signal changed(var patch)

    Layout.fillWidth: true
    spacing: 3

    property bool linked: false
    Component.onCompleted: root.linked = root.sides.every(s => root.valueOf(s) === root.valueOf(root.sides[0]))

    function has(side) {
        return root.sides.indexOf(side) >= 0
    }

    function valueOf(side) {
        return root.values[side] ?? 0
    }

    function limit(side) {
        return root.maxFor[side] ?? root.maxValue
    }

    function set(side, v) {
        const patch = {}
        if (root.linked) {
            for (const s of root.sides)
                patch[s] = Math.max(0, Math.min(root.limit(s), v))
        } else {
            patch[side] = Math.max(0, Math.min(root.limit(side), v))
        }
        root.changed(patch)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + 36
        color: Colors.surfaceContainerHigh
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: 5
        bottomRightRadius: 5

        GridLayout {
            id: grid
            anchors.fill: parent
            anchors.margins: 18
            columns: 3
            rowSpacing: 10
            columnSpacing: 12

            Item { Layout.preferredWidth: 150; Layout.preferredHeight: 1 }
            Stepper { side: "top"; label: "Top"; Layout.alignment: Qt.AlignHCenter }
            Item { Layout.preferredWidth: 150; Layout.preferredHeight: 1 }

            Stepper { side: "left"; label: "Left"; Layout.alignment: Qt.AlignCenter }

            Rectangle {
                id: preview
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                radius: 16
                color: Colors.surfaceContainerLow
                clip: true

                readonly property real k: root.mode === "pill" ? 1.4 : 1.6
                readonly property real barT: 12

                Rectangle {
                    visible: root.mode === "windows"
                    color: Colors.surfaceContainerHighest
                    x: root.barSide === "right" ? parent.width - preview.barT : 0
                    y: root.barSide === "bottom" ? parent.height - preview.barT : 0
                    width: root.barSide === "left" || root.barSide === "right" ? preview.barT : parent.width
                    height: root.barSide === "left" || root.barSide === "right" ? parent.height : preview.barT
                    topLeftRadius: root.barSide === "top" || root.barSide === "left" ? preview.radius : 0
                    topRightRadius: root.barSide === "top" || root.barSide === "right" ? preview.radius : 0
                    bottomLeftRadius: root.barSide === "bottom" || root.barSide === "left" ? preview.radius : 0
                    bottomRightRadius: root.barSide === "bottom" || root.barSide === "right" ? preview.radius : 0
                }

                Rectangle {
                    id: area
                    readonly property real insL: 8 + (root.mode === "windows" && root.barSide === "left" ? preview.barT : 0) + root.valueOf("left") * preview.k
                    readonly property real insR: 8 + (root.mode === "windows" && root.barSide === "right" ? preview.barT : 0) + root.valueOf("right") * preview.k
                    readonly property real insT: 8 + (root.mode === "windows" && root.barSide === "top" ? preview.barT : 0) + root.valueOf("top") * preview.k
                    readonly property real insB: 8 + (root.mode === "windows" && root.barSide === "bottom" ? preview.barT : 0) + root.valueOf("bottom") * preview.k

                    x: area.insL
                    y: area.insT
                    width: Math.max(0, parent.width - area.insL - area.insR)
                    height: root.mode === "pill" ? 18 : Math.max(0, parent.height - area.insT - area.insB)
                    radius: root.mode === "pill" ? 9 : 10
                    color: Qt.alpha(Colors.primary, root.mode === "pill" ? 0.55 : 0.12)
                    border.width: root.mode === "pill" ? 0 : 2
                    border.color: Colors.primary

                    Behavior on x { SpatialAnim { speed: "fast" } }
                    Behavior on y { SpatialAnim { speed: "fast" } }
                    Behavior on width { SpatialAnim { speed: "fast" } }
                    Behavior on height { SpatialAnim { speed: "fast" } }
                }

                Rectangle {
                    visible: root.mode === "pill"
                    x: 8
                    y: area.y + area.height + 10
                    width: parent.width - 16
                    height: parent.height - y - 8
                    radius: 10
                    color: Colors.surfaceContainerHighest
                    Behavior on y { SpatialAnim { speed: "fast" } }
                }

                CustomText {
                    anchors.centerIn: root.mode === "pill" ? undefined : area
                    anchors.horizontalCenter: root.mode === "pill" ? parent.horizontalCenter : undefined
                    y: root.mode === "pill" ? area.y + area.height + 10 + (parent.height - area.y - area.height - 18) / 2 - height / 2 : 0
                    content: "Windows"
                    size: 12
                    customColor: Colors.outline
                }
            }

            Stepper { side: "right"; label: "Right"; Layout.alignment: Qt.AlignCenter }

            Item { Layout.preferredWidth: 150; Layout.preferredHeight: 1 }
            Stepper { side: "bottom"; label: "Bottom"; Layout.alignment: Qt.AlignHCenter }
            Item { Layout.preferredWidth: 150; Layout.preferredHeight: 1 }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 56
        color: Colors.surfaceContainerHigh
        topLeftRadius: 5
        topRightRadius: 5
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            ColumnLayout {
                spacing: 2
                CustomText { content: root.linkLabel; size: 14 }
                CustomText { content: "One value for every edge"; size: 12; customColor: Colors.outline }
            }

            Item { Layout.fillWidth: true }

            CustomToogle {
                isToggleOn: root.linked
                onToggled: state => {
                    root.linked = state
                    if (state)
                        root.set(root.sides[0], root.valueOf(root.sides[0]))
                }
            }
        }
    }

    component Stepper: ColumnLayout {
        id: stepper

        property string side: "top"
        property string label: ""
        readonly property int value: root.valueOf(stepper.side)

        visible: root.has(stepper.side)
        spacing: 6

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: stepper.label
            size: 12
            customColor: Colors.outline
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: stepRow.implicitWidth + 8
            implicitHeight: 40
            radius: 20
            color: Colors.surfaceContainerHighest

            RowLayout {
                id: stepRow
                anchors.centerIn: parent
                spacing: 2

                M3IconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: "remove"
                    iconSize: 18
                    enabledButton: stepper.value > 0
                    onClicked: root.set(stepper.side, stepper.value - 1)
                }

                CustomText {
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignHCenter
                    content: stepper.value + " px"
                    size: 14
                    weight: 700
                    font.features: { "tnum": 1 }
                }

                M3IconButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: "add"
                    iconSize: 18
                    enabledButton: stepper.value < root.limit(stepper.side)
                    onClicked: root.set(stepper.side, stepper.value + 1)
                }
            }

            WheelHandler {
                onWheel: event => {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    if (d !== 0)
                        root.set(stepper.side, stepper.value + (d > 0 ? 1 : -1))
                }
            }
        }
    }
}
