import qs.modules.components.Bar
import QtQuick
import qs.modules.utils

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool rotatesWithBar: true

    implicitWidth: BarLayout.opt(root.itemId, "width") ?? 16
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        visible: !!root.host && root.host.editing
        radius: 6
        color: Qt.alpha(Colors.outline, 0.14)
    }
}
