import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.platform as Platform
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.components.custom
import "../../MaterialShapes/material-shapes.js" as MaterialShapeFn
import "../../MaterialShapes/shape-library.js" as ShapeLibrary

ShapeWidget {
    id: root
    configKey: "photoFrame"
    tile: WidgetSizes.small
    resizable: true
    minSpan: Qt.size(2, 2)
    maxSpan: Qt.size(4, 4)
    defaultPos: Qt.point(440, 440)

    readonly property string picked: SettingsConfig.widgets.photoFrameImage ?? ""
    readonly property string image: root.picked !== "" ? root.picked : (SettingsConfig.general.profile ?? "")
    readonly property string shapeLock: SettingsConfig.widgets.photoFrameShapeLock ?? ""

    readonly property int dayOfYear: {
        ServiceClock.date
        const d = new Date()
        return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000)
    }

    shape: {
        if (root.shapeLock !== "") return ShapeLibrary.get(root.shapeLock) ?? MaterialShapeFn.getCircle()
        switch (root.dayOfYear % 8) {
        case 1:  return MaterialShapeFn.getFlower()
        case 2:  return MaterialShapeFn.getClover4Leaf()
        case 3:  return MaterialShapeFn.getSunny()
        case 4:  return MaterialShapeFn.getGem()
        case 5:  return MaterialShapeFn.getPuffy()
        case 6:  return MaterialShapeFn.getCookie7Sided()
        case 7:  return MaterialShapeFn.getSoftBurst()
        default: return MaterialShapeFn.getCookie9Sided()
        }
    }

    function setWidgetKey(patch) {
        SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, patch)
    }

    optionsComponent: Component {
        ColumnLayout {
            spacing: 12

            ShapePicker {
                Layout.fillWidth: true
                selected: root.shapeLock
                autoHint: "A new shape every day"
                onPicked: name => root.setWidgetKey({ photoFrameShapeLock: name })
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 56
                radius: 18
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        CustomText { content: "Image"; size: 13; customColor: Colors.surfaceText }
                        CustomText {
                            Layout.fillWidth: true
                            content: root.picked !== "" ? root.picked : "Your profile photo"
                            size: 11
                            customColor: Colors.outline
                            elide: Text.ElideLeft
                        }
                    }

                    M3IconButton {
                        visible: root.picked !== ""
                        implicitWidth: 34
                        implicitHeight: 34
                        icon: "restart_alt"
                        iconSize: 17
                        onClicked: root.setWidgetKey({ photoFrameImage: "" })
                    }

                    M3IconButton {
                        implicitWidth: 34
                        implicitHeight: 34
                        icon: "image"
                        iconSize: 17
                        onClicked: {
                            GlobalStates.fileDialogOpen = true
                            photoPicker.open()
                        }
                    }
                }
            }

            Platform.FileDialog {
                id: photoPicker
                title: "Select a photo"
                nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.gif)"]
                onAccepted: {
                    root.setWidgetKey({ photoFrameImage: photoPicker.file.toString().replace(/^file:\/\//, "") })
                    GlobalStates.fileDialogOpen = false
                }
                onRejected: GlobalStates.fileDialogOpen = false
            }
        }
    }

    Item {
        id: photoLayer
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Image {
            id: photo
            anchors.centerIn: parent
            width: root.faceSize
            height: root.faceSize
            source: root.image
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 600
            sourceSize.height: 600
            asynchronous: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: photo.status === Image.Ready
        source: photoLayer
        maskEnabled: true
        maskSource: root.shapeTexture
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    MaterialIconSymbol {
        anchors.centerIn: parent
        visible: photo.status !== Image.Ready
        content: "image"
        iconSize: Math.round(root.faceSize * 0.22)
        customColor: Colors.outline
    }
}
