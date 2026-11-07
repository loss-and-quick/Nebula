import QtQuick
import qs.modules.utils
import qs.modules.components.custom

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    readonly property string symbol: BarLayout.opt(root.itemId, "symbol") ?? "favorite"
    readonly property real size: BarLayout.opt(root.itemId, "size") ?? 18
    readonly property string role: BarLayout.opt(root.itemId, "role") ?? "primary"
    readonly property bool chip: BarLayout.opt(root.itemId, "chip") === true

    implicitWidth: root.chip ? root.size + 14 : root.size + 6
    implicitHeight: root.chip ? root.size + 10 : root.size

    Rectangle {
        anchors.centerIn: parent
        visible: root.chip
        width: root.size + 14
        height: root.size + 10
        radius: height / 2
        color: Qt.alpha(BarLayout.roleColor(root.role), 0.18)
    }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.symbol
        iconSize: root.size
        customColor: BarLayout.roleColor(root.role)
        elide: Text.ElideNone
    }
}
