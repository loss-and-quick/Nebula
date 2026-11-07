import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.components.custom

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, 0, 0)
    readonly property bool shown: root.showLayout || root.capsOn

    readonly property bool showLayout: BarLayout.opt(root.itemId, "layout") !== false
    readonly property bool showCaps: BarLayout.opt(root.itemId, "caps") !== false

    readonly property bool capsOn: ServiceKeyboard.capsLockOn

    implicitWidth: row.implicitWidth
    implicitHeight: 26

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showCaps && root.capsOn
            width: capsRow.implicitWidth + 10
            height: 26
            radius: 13
            color: Colors.primary

            Row {
                id: capsRow
                anchors.centerIn: parent
                spacing: 3
                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "keyboard_capslock"
                    iconSize: 16
                    customColor: Colors.primaryText
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "CAPS"
                    size: 11
                    weight: 700
                    customColor: Colors.primaryText
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showLayout
            width: layoutRow.implicitWidth + 10
            height: 26
            radius: 13
            color: root.plateless ? (hov.containsMouse ? BarLayout.tintHover(root.itemId) : Qt.alpha(BarLayout.tintHover(root.itemId), 0))
                : hov.containsMouse ? Colors.primaryContainer : Colors.surfaceContainer
            Behavior on color { EffectsColorAnim {} }

            Row {
                id: layoutRow
                anchors.centerIn: parent
                spacing: 5
                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "keyboard"
                    iconSize: 16
                    customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceVariantText
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: ServiceKeyboard.code
                    size: 12
                    weight: 700
                    customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                }
            }

            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ServiceKeyboard.switchNext()
            }

            CustomToolTip {
                content: (ServiceKeyboard.keymap !== "" ? ServiceKeyboard.keymap : "Keyboard layout") + " · click to switch"
                visible: hov.containsMouse
            }
        }
    }

}
