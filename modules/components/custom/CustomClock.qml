import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.components.custom
import qs.modules.services
import qs.modules.settings

Item{
    id: root
    anchors.centerIn: parent
    implicitWidth: row.implicitWidth

    property bool use24: false

    readonly property int shownHour: {
        const h = parseInt(ServiceClock.hour)
        if (root.use24)
            return h
        const m = h % 12
        return m === 0 ? 12 : m
    }

    property string hourDigit1: Math.floor(root.shownHour / 10).toString()
    property string hourDigit2: (root.shownHour % 10).toString()
    property string minuteDigit1: ServiceClock.minute[0];
    property string minuteDigit2: ServiceClock.minute[1];
    property real fontSize: 30
    property real fontX: 3
    property real ring: 2
    property int ringSteps: 12



    //color: "transparent"
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: -3

        Item {
            Layout.preferredWidth: text1.implicitWidth
            Layout.preferredHeight: text1.implicitHeight

            CustomText {
                id: text1
                content: hourDigit1
                size: root.fontSize
                color: Colors.surfaceText
                layer.enabled: true
                visible: false
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Colors.outline
                weight: 600
            }

            Item {
                id: maskItem
                width: text1.implicitWidth
                height: text1.implicitHeight
                layer.enabled: true
                visible: false

                CustomText {
                    id: child
                    content: root.hourDigit2
                    size: root.fontSize
                    weight: 600
                    color: "white"
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                    x: text1.implicitWidth - root.fontX
                }

                Repeater {
                    model: root.ringSteps

                    CustomText {
                        required property int index

                        readonly property real angle: index * 2 * Math.PI / root.ringSteps

                        content: root.hourDigit2
                        size: root.fontSize
                        weight: 600
                        color: "white"
                        font.family: SettingsConfig.general.displayFont ?? "Titan One"
                        x: text1.implicitWidth - root.fontX + root.ring * Math.cos(angle)
                        y: root.ring * Math.sin(angle)
                    }
                }
            }

            MultiEffect {
                source: text1
                x: 0; y: 0
                width: text1.implicitWidth
                height: text1.implicitHeight
                maskEnabled: true
                maskSource: maskItem
                maskInverted: true
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        } 
        CustomText {
            content: hourDigit2
            size: root.fontSize
            color:Colors.primary
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
            style: Text.Raised
            styleColor: Colors.outline
            weight: 600
        }

        CustomText{
            Layout.leftMargin: 5
            Layout.rightMargin: 5
            content: ":"
            size: root.fontSize
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
            bottomPadding: 5
            color: Colors.primary
            style: Text.Raised
            styleColor: Colors.outline
            weight: 600
        }

        Item {
            Layout.preferredWidth: text2.implicitWidth
            Layout.preferredHeight: text2.implicitHeight

            CustomText {
                id: text2
                content: minuteDigit1
                size: root.fontSize
                color: Colors.surfaceText
                layer.enabled: true
                visible: false
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Colors.outline
                weight: 600
            }

            Item {
                id: maskItem2
                width: text2.implicitWidth
                height: text2.implicitHeight
                layer.enabled: true
                visible: false

                CustomText {
                    id: child2
                    content: root.minuteDigit2
                    size: root.fontSize
                    weight: 600
                    color: "white"
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                    x: text2.implicitWidth - root.fontX
                }

                Repeater {
                    model: root.ringSteps

                    CustomText {
                        required property int index

                        readonly property real angle: index * 2 * Math.PI / root.ringSteps

                        content: root.minuteDigit2
                        size: root.fontSize
                        weight: 600
                        color: "white"
                        font.family: SettingsConfig.general.displayFont ?? "Titan One"
                        x: text2.implicitWidth - root.fontX + root.ring * Math.cos(angle)
                        y: root.ring * Math.sin(angle)
                    }
                }
            }

            MultiEffect {
                source: text2
                x: 0; y: 0
                width: text2.implicitWidth
                height: text2.implicitHeight
                maskEnabled: true
                maskSource: maskItem2
                maskInverted: true
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        } 
        CustomText {
            content: minuteDigit2
            size: root.fontSize
            color:Colors.primary
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
            style: Text.Raised
            styleColor: Colors.outline
            weight: 600
        }

    }
}
