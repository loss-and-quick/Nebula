import QtQuick
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.components.custom

ClippingRectangle {
    id: root

    property string source: ""
    property int decode: Math.max(256, Math.ceil(Math.max(root.width, root.height) * 2))

    color: Colors.primaryContainer

    Rectangle {
        visible: art.status !== Image.Ready
        x: parent.width * 0.4
        y: parent.height * 0.14
        width: parent.width * 0.48
        height: width
        radius: width / 2
        color: Colors.primary
    }

    Rectangle {
        visible: art.status !== Image.Ready
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.28
        color: Colors.primaryContainerText
    }

    Image {
        id: art
        anchors.fill: parent
        source: root.source
        visible: status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.decode
        sourceSize.height: root.decode
        asynchronous: true
        mipmap: true
    }
}
