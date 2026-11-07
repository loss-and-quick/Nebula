import QtQuick
import Nebula

ShapePainter {
    id: root

    property var roundedPolygon: null
    property string prevRoundedPolygon: ""
    property bool _applied: false

    property Animation animation: NumberAnimation {
        duration: 350
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
    }

    implicitWidth: root.boundsWidth
    implicitHeight: root.boundsHeight

    function _apply(animate) {
        const next = root.roundedPolygon ?? ""
        root.fromShape = root.prevRoundedPolygon !== "" ? root.prevRoundedPolygon : next
        root.toShape = next
        morphBehavior.enabled = false
        root.progress = animate ? 0 : 1
        morphBehavior.enabled = true
        root.progress = 1
        root.prevRoundedPolygon = next
        root._applied = true
    }

    onRoundedPolygonChanged: root._apply(true)
    Component.onCompleted: if (!root._applied) root._apply(false)

    Behavior on progress {
        id: morphBehavior
        animation: root.animation
    }
}
