import qs.modules.components.Bar
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.components.custom
import qs.modules.services
import qs.modules.settings

Flickable {
    id: root
    anchors.fill: parent
    signal backClicked

    contentWidth: width
    contentHeight: col.height + 28
    interactive: contentHeight > height + 1
    boundsBehavior: Flickable.StopAtBounds
    clip: interactive

    opacity: 0
    EffectsAnim on opacity {
        speed: "slow"
        from: 0
        to: 1
        running: true
    }

    readonly property var descriptions: ["Lowest power draw", "Default balance", "Maximum performance"]

    ColumnLayout {
        id: col
        x: 14
        y: 14
        width: root.width - 28
        height: Math.max(root.height - 28, implicitHeight)
        spacing: 8

        CustomText {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            content: "Power Modes"
            size: 17
            weight: 700
            horizontalAlignment: Text.AlignHCenter
        }

        // Degradation warning banner (thermal throttling, lap detected)
        Rectangle {
            visible: ServiceUPower.isDegraded
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 14
            color: Qt.alpha(Colors.error, 0.15)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                MaterialIconSymbol {
                    content: "warning"
                    iconSize: 18
                    customColor: Colors.error
                }

                CustomText {
                    Layout.fillWidth: true
                    content: ServiceUPower.degradationText
                    size: 11
                    weight: 600
                    customColor: Colors.error
                    elide: Text.ElideRight
                }
            }
        }

        // Active profile holds (e.g. Steam, game, render tool)
        Repeater {
            model: ServiceUPower.holds
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 14
                color: Qt.alpha(Colors.primary, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialIconSymbol {
                        content: "lock"
                        iconSize: 16
                        customColor: Colors.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        CustomText {
                            Layout.fillWidth: true
                            content: "Held by " + (modelData.applicationId || "Application")
                            size: 11
                            weight: 700
                            customColor: Colors.primary
                            elide: Text.ElideRight
                        }

                        CustomText {
                            visible: modelData.reason.length > 0
                            Layout.fillWidth: true
                            content: modelData.reason
                            size: 10
                            customColor: Colors.outline
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // PPD not active warning
        Rectangle {
            visible: !ServiceUPower.ppdAvailable
            Layout.fillWidth: true
            implicitHeight: noPpdCol.implicitHeight + 20
            radius: 16
            color: Qt.alpha(Colors.outline, 0.1)

            ColumnLayout {
                id: noPpdCol
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 4

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: "power_off"
                    iconSize: 24
                    customColor: Colors.outline
                }

                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    content: "Power Profiles daemon is inactive"
                    size: 12
                    weight: 700
                    customColor: Colors.surfaceText
                }

                CustomText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    content: "Enable power-profiles-daemon service to switch power modes."
                    size: 10
                    customColor: Colors.outline
                    wrapMode: Text.WordWrap
                }
            }
        }

        Repeater {
            model: ServiceUPower.availableProfiles

            delegate: Rectangle {
                id: modeRow
                required property var modelData
                required property int index

                readonly property bool active: ServiceUPower.powerProfile === modeRow.modelData.id

                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 18
                color: modeRow.active ? Qt.alpha(Colors.primary, 0.18) : modeArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                Behavior on color {
                    EffectsColorAnim {}
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: modeRow.active ? Colors.primary : Colors.surfaceContainerHighest
                        Behavior on color {
                            EffectsColorAnim {}
                        }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: modeRow.modelData.icon
                            iconSize: 19
                            customColor: modeRow.active ? Colors.primaryText : Colors.surfaceVariantText
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        CustomText {
                            Layout.fillWidth: true
                            content: modeRow.modelData.name
                            size: 14
                            weight: 700
                            elide: Text.ElideRight
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: modeRow.active ? "Active" : (modeRow.modelData.description || root.descriptions[modeRow.modelData.id] || "Off")
                            size: 11
                            customColor: modeRow.active ? Colors.primary : Colors.outline
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: modeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceUPower.setPowerProfile(modeRow.modelData.id)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: doneLabel.implicitWidth + 40
                radius: 20
                color: Colors.primary

                CustomText {
                    id: doneLabel
                    anchors.centerIn: parent
                    content: "Done"
                    size: 13
                    weight: 700
                    customColor: Colors.primaryText
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backClicked()
                }
            }
        }
    }
}
