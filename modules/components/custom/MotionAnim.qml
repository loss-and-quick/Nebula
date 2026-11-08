import QtQuick
import qs.modules.settings

NumberAnimation {
    property string role: ""
    property string speed: "default"

    duration: MotionRegistry.durationFor(role, speed)
    easing.type: MotionRegistry.easingTypeFor(role)
    easing.bezierCurve: MotionRegistry.curveFor(role, speed)
}
