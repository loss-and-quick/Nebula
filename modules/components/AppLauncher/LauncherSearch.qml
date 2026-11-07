import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.components.custom

Rectangle {
    id: root

    required property Item launcher
    property alias text: input.text
    readonly property alias cursorPosition: input.cursorPosition
    property int fontSize: 15
    property string placeholder: ""
    property color iconColor: Colors.primary

    implicitHeight: 50
    radius: 16
    color: Colors.surfaceContainerHigh

    function focusInput() {
        input.forceActiveFocus()
    }

    Component.onCompleted: root.launcher.searchField = root
    Component.onDestruction: if (root.launcher.searchField === root) root.launcher.searchField = null

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.max(14, root.radius * 0.6)
        anchors.rightMargin: 10
        spacing: 10

        MaterialIconSymbol {
            content: "search"
            iconSize: Math.round(root.fontSize * 1.3)
            customColor: root.iconColor
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            CustomText {
                id: hintProbe
                visible: false
                content: ServiceLauncher.hint
                size: root.fontSize
            }

            CustomText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                content: root.placeholder !== "" ? root.placeholder
                    : hintProbe.implicitWidth <= parent.width ? ServiceLauncher.hint : "Search apps"
                size: root.fontSize
                customColor: Colors.outline
                elide: Text.ElideRight
                visible: input.text.length === 0
            }

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                font.pixelSize: root.fontSize
                font.weight: 600
                font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                color: Colors.surfaceText
                focus: !root.launcher.preview
                onTextChanged: root.launcher.updateQuery(text)
                onAccepted: root.launcher.activateSelected()
                Keys.onPressed: event => root.launcher.handleKey(event)
            }
        }

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 10
            color: Colors.surfaceContainerHighest
            visible: input.text.length > 0

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "close"
                iconSize: 14
                customColor: Colors.outline
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launcher.setQuery("")
            }
        }
    }
}
