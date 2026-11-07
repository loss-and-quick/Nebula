import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.components.custom

ColumnLayout {
    id: root

    required property Item launcher
    spacing: 8

    Binding {
        target: root.launcher
        property: "modeView"
        value: root.launcher.isEmoji ? emojiLoader.item : resultsLoader.item
    }

    LauncherModeBar {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        detail: root.launcher.isEmoji && emojiLoader.item && ServiceLauncher.results.length > 0
            ? emojiLoader.item.activeName : ""
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Loader {
            id: emojiLoader
            anchors.fill: parent
            active: root.launcher.isEmoji
            visible: active
            sourceComponent: EmojiGrid {
                onActivated: root.launcher.closed()
            }
        }

        Loader {
            id: resultsLoader
            anchors.fill: parent
            active: !root.launcher.isApps && !root.launcher.isEmoji
            visible: active
            sourceComponent: LauncherResults {
                onActivated: root.launcher.closed()
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            visible: ServiceLauncher.results.length === 0 && ServiceLauncher.term.length > 0

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: "search_off"
                iconSize: 30
                customColor: Colors.outline
            }
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "No results"
                size: 13
                customColor: Colors.outline
            }
        }
    }
}
