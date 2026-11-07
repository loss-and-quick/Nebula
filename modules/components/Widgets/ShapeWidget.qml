import QtQuick
import qs.modules.utils
import "../../MaterialShapes/" as MaterialShapes
import "../../MaterialShapes/material-shapes.js" as MaterialShapeFn

WidgetHost {
    id: root

    property var shape: MaterialShapeFn.getCircle()
    property color faceColor: WidgetSizes.cardColor
    property bool showFace: true
    property real faceRotation: 0
    readonly property real faceSize: Math.min(width, height)
    readonly property Item shapeTexture: shapeMask

    backdropMask: shapeMask

    MaterialShapes.ShapeCanvas {
        z: -2
        visible: root.showFace
        anchors.centerIn: parent
        width: root.faceSize
        height: root.faceSize
        rotation: root.faceRotation
        roundedPolygon: root.shape
        color: root.faceColor
    }

    Item {
        id: maskSource
        anchors.fill: parent

        MaterialShapes.ShapeCanvas {
            anchors.centerIn: parent
            width: root.faceSize
            height: root.faceSize
            rotation: root.faceRotation
            roundedPolygon: root.shape
            color: "white"
        }
    }

    Item {
        width: 0
        height: 0
        clip: true

        ShaderEffectSource {
            id: shapeMask
            width: root.width
            height: root.height
            textureSize: Qt.size(root.width, root.height)
            sourceItem: maskSource
            hideSource: true
            live: true
        }
    }
}
