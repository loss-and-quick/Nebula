import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Templates as T
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

T.Control {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property color customColor: highlighted || checked ? Colors.primary : Colors.surfaceText
    property Component leadingComponent: null
    property Component trailingComponent: null
    property alias color: container.color
    property alias radius: container.radius
    property bool checkable: false
    property bool checked: false
    property bool highlighted: false
    readonly property bool down: mouseArea.pressed || keyboardDown
    property bool keyboardDown: false

    signal clicked()
    signal pressAndHold()

    function activate() {
        if (checkable)
            checked = !checked
        clicked()
    }

    function startRipple(x, y) {
        rippleAnimation.px = x
        rippleAnimation.py = y
        rippleAnimation.diameter = 2 * Math.sqrt(Math.max(x * x + y * y, (width - x) * (width - x) + y * y, x * x + (height - y) * (height - y), (width - x) * (width - x) + (height - y) * (height - y)))
        rippleAnimation.restart()
    }

    implicitWidth: Math.max(200, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(sublabel !== "" ? 72 : 56, implicitContentHeight + topPadding + bottomPadding)
    padding: 16
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    Accessible.role: Accessible.Button
    Accessible.name: label !== "" ? label : icon
    Accessible.checkable: checkable
    Accessible.checked: checked

    Keys.onPressed: event => {
        if (!event.isAutoRepeat && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            keyboardDown = true
            startRipple(width / 2, height / 2)
            event.accepted = true
        }
    }
    Keys.onReleased: event => {
        if (!event.isAutoRepeat && keyboardDown && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            keyboardDown = false
            activate()
            event.accepted = true
        }
    }
    onActiveFocusChanged: if (!activeFocus) keyboardDown = false

    contentItem: RowLayout {
        spacing: 16

        Loader {
            visible: root.leadingComponent !== null
            active: visible
            sourceComponent: root.leadingComponent
        }

        MaterialIconSymbol {
            visible: root.leadingComponent === null && root.icon !== ""
            content: root.icon
            iconSize: 24
            customColor: root.customColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2

            CustomText {
                Layout.fillWidth: true
                visible: root.label !== ""
                content: root.label
                elide: Text.ElideRight
                size: 14
                customColor: root.customColor
            }

            CustomText {
                Layout.fillWidth: true
                visible: root.sublabel !== ""
                content: root.sublabel
                elide: Text.ElideRight
                size: 12
                customColor: Colors.outline
            }
        }

        Loader {
            visible: root.trailingComponent !== null
            active: visible
            sourceComponent: root.trailingComponent
        }
    }

    background: Rectangle {
        id: container

        color: root.highlighted || root.checked ? Colors.primaryContainer : Colors.surfaceContainerHigh
        radius: 12
        border.width: root.visualFocus ? 1 : 0
        border.color: Colors.primary
        Behavior on radius { NumberAnimation { duration: M3Motion.container.radiusDuration } }

        Rectangle {
            anchors.fill: parent
            radius: container.radius
            color: root.down ? Qt.alpha(Colors.surfaceText, 0.12) : root.hovered ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }
        }

        Item {
            anchors.fill: parent
            layer.enabled: rippleAnimation.running
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: rippleMask
            }

            Rectangle {
                id: rippleMask
                anchors.fill: parent
                radius: container.radius
                visible: false
                layer.enabled: true
            }

            Rectangle {
                id: ripple
                width: 0
                height: width
                radius: width / 2
                color: Qt.alpha(Colors.surfaceText, 0.12)
                opacity: 0
                transform: Translate { x: -ripple.width / 2; y: -ripple.height / 2 }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onPressed: mouse => root.startRipple(mouse.x, mouse.y)
            onClicked: root.activate()
            onPressAndHold: root.pressAndHold()
        }
    }

    SequentialAnimation {
        id: rippleAnimation
        property real px: 0
        property real py: 0
        property real diameter: 0

        PropertyAction { target: ripple; property: "x"; value: rippleAnimation.px }
        PropertyAction { target: ripple; property: "y"; value: rippleAnimation.py }
        PropertyAction { target: ripple; property: "width"; value: 0 }
        PropertyAction { target: ripple; property: "opacity"; value: 1 }
        NumberAnimation { target: ripple; property: "width"; to: rippleAnimation.diameter; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 150 }
    }
}
