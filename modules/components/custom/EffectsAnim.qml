import QtQuick
import qs.modules.settings

NumberAnimation {
    property string role: ""
    property string speed: "default"

    duration: role !== "" ? MotionRegistry.durationFor(role, speed) : M3Motion.effectsDuration(speed)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: role !== "" ? MotionRegistry.curveFor(role, speed) : M3Motion.effects.curve
}
