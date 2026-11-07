import QtQuick
import QtQuick.Templates as T
import qs.modules.utils
import qs.modules.settings
import qs.modules.components.custom

T.Control {
    id: root

    property string icon: ""
    property int iconSize: 20
    property color iconColor: Colors.surfaceText
    property color iconHoverColor: Colors.primaryText
    property int iconFill: 0
    property bool enabledButton: true
    property string tip: ""
    property bool square: false
    property real squareRadius: 12
    property real pressedRadius: 8
    property alias color: container.color
    property alias radius: container.radius
    property alias border: container.border
    property alias topLeftRadius: container.topLeftRadius
    property alias topRightRadius: container.topRightRadius
    property alias bottomLeftRadius: container.bottomLeftRadius
    property alias bottomRightRadius: container.bottomRightRadius
    property bool _keyboardDown: false
    readonly property bool down: ripple.pressed || _keyboardDown

    signal clicked
    signal rightClicked

    implicitWidth: 40
    implicitHeight: 40
    enabled: enabledButton
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    opacity: enabledButton ? 1 : 0.6
    Accessible.role: Accessible.Button
    Accessible.name: tip !== "" ? tip : icon

    Keys.onPressed: event => {
        if (!event.isAutoRepeat && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            _keyboardDown = true
            ripple.trigger(width / 2, height / 2)
            event.accepted = true
        }
    }
    Keys.onReleased: event => {
        if (!event.isAutoRepeat && _keyboardDown && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            _keyboardDown = false
            clicked()
            event.accepted = true
        }
    }
    onActiveFocusChanged: if (!activeFocus) _keyboardDown = false

    radius: down ? pressedRadius : (square ? squareRadius : height / 2)
    Behavior on radius {
        NumberAnimation {
            duration: M3Motion.container.radiusDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: M3Motion.container.curve
        }
    }
    color: Colors.surfaceContainerHighest
    Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }

    contentItem: Item {
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: root.icon
            iconSize: root.down ? root.iconSize * 0.9 : root.iconSize
            Behavior on iconSize { SpatialAnim { speed: "fast" } }
            fill: root.iconFill
            color: root.iconColor
            Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }
            Behavior on fill { NumberAnimation { duration: M3Motion.effects.defaultDuration } }
        }
    }

    background: Rectangle {
        id: container

        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
            color: root.hovered || root.visualFocus ? Qt.alpha(root.iconColor, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }
        }
    }

    RippleEffect {
        id: ripple
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        enabled: root.enabled
        hoverColor: "transparent"
        rippleColor: Qt.alpha(root.iconColor, 0.20)
        onClicked: root.clicked()
        onRightClicked: root.rightClicked()
    }

    CustomToolTip { content: root.tip; visible: root.tip !== "" && root.hovered && !root.down }
}
