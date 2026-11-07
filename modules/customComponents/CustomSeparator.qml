import QtQuick
import QtQuick.Templates as T
import qs.modules.utils

T.ToolSeparator {
    id: root

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    contentItem: Rectangle {
        implicitWidth: root.vertical ? 1 : 30
        implicitHeight: root.vertical ? 30 : 1
        color: Colors.surfaceContainerHigh
    }
}
