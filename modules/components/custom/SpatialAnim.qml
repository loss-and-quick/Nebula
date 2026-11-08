import QtQuick
import qs.modules.settings

NumberAnimation {
    property string role: ""
    property string speed: "default"

    duration: role !== "" ? MotionRegistry.durationFor(role, speed) : M3Motion.spatialDuration(speed)
    easing.type: role !== "" ? MotionRegistry.easingTypeFor(role) : Easing.BezierSpline
    easing.bezierCurve: role !== "" ? MotionRegistry.curveFor(role, speed) : M3Motion.spatialCurve(speed)
    easing.overshoot: role !== "" ? MotionRegistry.overshootFor(role) : 1.70158
    easing.amplitude: role !== "" ? MotionRegistry.amplitudeFor(role) : 1.0
    easing.period: role !== "" ? MotionRegistry.periodFor(role) : 0.3
}
