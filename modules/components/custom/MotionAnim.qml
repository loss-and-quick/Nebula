import QtQuick
import qs.modules.settings

NumberAnimation {
    property string role: ""
    property string speed: "default"

    duration: MotionRegistry.durationFor(role, speed)
    easing.type: MotionRegistry.easingTypeFor(role)
    easing.bezierCurve: MotionRegistry.curveFor(role, speed)
    easing.overshoot: MotionRegistry.overshootFor(role)
    easing.amplitude: MotionRegistry.amplitudeFor(role)
    easing.period: MotionRegistry.periodFor(role)
}
