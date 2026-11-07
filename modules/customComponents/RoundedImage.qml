import QtQuick
import QtQuick.Effects

Item {
    id: root

    property alias source: img.source
    property alias sourceSize: img.sourceSize
    property alias asynchronous: img.asynchronous
    property alias status: img.status
    property alias fillMode: img.fillMode
    property real radius: 28

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
        }
    }
}
