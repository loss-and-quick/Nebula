import QtQuick
import QtQuick.Shapes
import qs.modules.utils

Item {
    id: root

    property real value: 0
    property int segments: 12
    property real gapDegrees: 7
    property real thickness: Math.max(3, root.size * 0.12)
    property color color: Colors.primary
    property color fillColor: Colors.secondary
    property color trackColor: Colors.surfaceContainerHighest

    readonly property real size: Math.min(root.width, root.height)
    readonly property real r: root.size / 2 - root.thickness / 2
    readonly property int lit: Math.round(Math.max(0, Math.min(1, root.value)) * root.segments)
    readonly property real step: 360 / Math.max(1, root.segments)

    Repeater {
        model: root.segments

        delegate: Shape {
            id: seg
            required property int index

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: seg.index >= root.lit ? root.trackColor
                           : seg.index === root.lit - 1 ? root.color : root.fillColor
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: root.width / 2
                    centerY: root.height / 2
                    radiusX: root.r
                    radiusY: root.r
                    startAngle: -90 + seg.index * root.step + root.gapDegrees / 2
                    sweepAngle: root.step - root.gapDegrees
                }
            }
        }
    }
}
