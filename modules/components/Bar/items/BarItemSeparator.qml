import qs.modules.components.Bar
import QtQuick
import qs.modules.utils

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool rotatesWithBar: true

    readonly property string style: BarLayout.opt(root.itemId, "style") ?? "line"
    readonly property real thickness: BarLayout.opt(root.itemId, "thickness") ?? 1
    readonly property real lineHeight: BarLayout.opt(root.itemId, "height") ?? 18

    implicitWidth: root.style === "dot" ? root.thickness + 11 : root.style === "gap" ? 4 + root.thickness * 4 : root.style === "accent" ? root.thickness + 9 : root.thickness + 8
    implicitHeight: 32

    Rectangle {
        anchors.centerIn: parent
        visible: root.style !== "gap"
        width: root.style === "dot" ? root.thickness + 3 : root.style === "accent" ? root.thickness + 1 : root.thickness
        height: root.style === "dot" ? width : root.style === "accent" ? root.lineHeight * 0.8 : root.lineHeight
        radius: width / 2
        color: root.style === "accent" ? Qt.alpha(Colors.primary, 0.7) : root.style === "dot" ? Colors.outline : Colors.outlineVariant
    }
}
