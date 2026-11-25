import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings

Rectangle {
    id: root
    property bool isListClicked: false
    property var currentVal
    property var _picked: null
    readonly property var shownVal: root._picked ?? root.currentVal
    onCurrentValChanged: root._picked = null

    Timer {
        id: pickedTimer
        interval: 1500
        onTriggered: root._picked = null
    }
    property var list: []
    color: Colors.surfaceContainerHighest
    radius: 10
    z: isListClicked ? 1000 : 0
    signal listClicked
    signal listChildClicked(var child)
    height: 30

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.isListClicked = true;
            root.listClicked();
        }
    }

    RowLayout {
        //visible: !root.isListClicked && root.height === 30
        anchors.fill: parent
        anchors.margins: 5
        anchors.leftMargin: 10
        CustomText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            content: root.shownVal
            size: 12
            weight: 600
        }

        MaterialIconSymbol {
            content: "keyboard_arrow_down"
            iconSize: 20
        }
    }

    Loader {
        id: listLoader
        active: root.isListClicked
        sourceComponent: PopupWindow {
            id: popup
            anchor.window: layout
            visible: true
            implicitWidth: root.width
            implicitHeight: Math.min(listView.contentHeight + 10, 250)
            color: "transparent"

            HyprlandFocusGrab {
                active: true
                windows: [QsWindow.window]
                onCleared: morph.close()
            }

            property var windowPos: layout?.mapFromItem(root, 0, root.height) ?? Qt.point(0, 0)

            anchor {
                rect.x: windowPos.x
                rect.y: windowPos.y - root.height
            }

            MorphCard {
                id: morph
                autoOpen: true
                anchors.fill: parent

                srcWidth: root.width
                srcHeight: root.height
                srcRadius: root.radius

                contentHeight: Math.min(listView.contentHeight + 10, 250)
                cardRadius: 10
                cardColor: root.color
                cardBorderWidth: 1
                cardBorderColor: Colors.outline

                onCloseFinished: root.isListClicked = false

                ListView {
                    id: listView
                    anchors {
                        fill: parent
                        margins: 5
                    }
                    orientation: Qt.Vertical
                    model: root.list
                    spacing: 5
                    clip: true

                    delegate: Rectangle {
                        implicitWidth: ListView.view.width
                        implicitHeight: 32
                        radius: 8
                        readonly property bool isSelected: root.shownVal === modelData.description
                        color: isSelected ? Qt.alpha(Colors.primary, 0.16) : area.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                        Behavior on color { EffectsColorAnim {} }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            CustomText {
                                Layout.fillWidth: true
                                content: modelData.description
                                size: 12
                                weight: isSelected ? 600 : 400
                                elide: Text.ElideRight
                                customColor: isSelected ? Colors.primary : Colors.surfaceText
                            }

                            MaterialIconSymbol {
                                visible: isSelected
                                content: "check"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                morph.close();
                                root._picked = modelData.description;
                                pickedTimer.restart();
                                root.listChildClicked(modelData);
                            }
                        }
                    }
                }
            }
        }
    }

    // ColumnLayout{
    //     visible: root.isListClicked
    //     anchors.fill: parent
    //     anchors.margins: 10
    //
    //     Rectangle{
    //         Layout.preferredWidth: parent.width
    //         Layout.preferredHeight: 30
    //         radius: 10
    //         color: Colors.surfaceContainerHigh
    //
    //         RowLayout{
    //             anchors.fill: parent
    //             anchors.margins: 5
    //             CustomIconImage{
    //                 icon: "search"
    //                 size: 14
    //             }
    //
    //             TextInput{
    //                 Layout.fillWidth: true
    //                 Layout.fillHeight: true
    //                 verticalAlignment: TextInput.AlignVCenter
    //
    //                 focus: true
    //                 clip: true
    //                 text: root.currentVal
    //                 font.pixelSize: 12
    //                 color: Colors.inverseSurface
    //
    //             }
    //         }
    //     }
    //
    //     ListView{
    //         visible: root.isListClicked
    //         Layout.fillHeight: true
    //         Layout.topMargin: 5
    //         orientation: Qt.Vertical
    //         Layout.preferredWidth: parent.width
    //         model: root.list
    //         spacing: 5
    //
    //         delegate: Rectangle{
    //             implicitWidth: ListView.view.width
    //             implicitHeight: 20
    //             radius: 5
    //             color: root.currentVal === modelData.name ? Colors.primary : area.containsMouse ? Qt.alpha(Colors.primary, 0.5) : "transparent"
    //             CustomText{
    //                 anchors.left:parent.left
    //                 anchors.verticalCenter: parent.verticalCenter
    //                 anchors.leftMargin: 5
    //                 content: modelData.name
    //                 width: text.width
    //                 size: 12
    //                 weight: 600
    //                 color: root.currentVal === modelData.name ? Colors.primaryText : Colors.surfaceVariantText
    //             }
    //
    //             MouseArea{
    //                 id: area
    //                 anchors.fill: parent
    //                 cursorShape: Qt.PointingHandCursor
    //                 hoverEnabled: true
    //
    //                 onClicked:{
    //                     root.isListClicked = false
    //
    //                     root.currentVal = modelData.name
    //                     root.listChildClicked(modelData.name)
    //                 }
    //             }
    //         }
    //     }
    //
    // }
}
