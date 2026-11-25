import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.components.custom
import Quickshell.Hyprland
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

Item {
    id: root

    property var appEntry: null
    readonly property var desktopApp: ServiceApps.resolveApp(root.appEntry?.appId ?? "")
    readonly property string appName: root.desktopApp?.name
                                     ?? DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.name
                                     ?? root.appEntry?.appId ?? ""
    readonly property string appIcon: root.desktopApp?.icon
                                     ?? DesktopEntries.heuristicLookup(root.appEntry?.appId ?? "")?.icon ?? ""

    readonly property var appActions: {
        const out = [];
        const acts = root.desktopApp?.actions ?? [];
        for (let i = 0; i < acts.length; i++) {
            if (acts[i] && acts[i].name)
                out.push(acts[i]);
        }
        return out;
    }

    implicitWidth: 230
    implicitHeight: menuCol.implicitHeight + 16

    signal close

    Item {
        id: menuRect
        anchors.fill: parent

        ColumnLayout {
            id: menuCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 6

            // ── App header ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 14
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Image {
                        width: 32
                        height: 32
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        source: IconUtil.getDesktopIconPath(root.appIcon, "image-missing")
                        sourceSize.width: 96
                        sourceSize.height: 96
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        CustomText {
                            Layout.fillWidth: true
                            content: root.appName
                            size: 13
                            weight: 700
                            elide: Text.ElideRight
                        }
                        CustomText {
                            content: {
                                var n = root.appEntry?.toplevels?.length ?? 0;
                                return n > 0 ? n + " window" + (n > 1 ? "s open" : " open") : "Not running";
                            }
                            size: 10
                            customColor: Colors.outline
                        }
                    }
                }
            }

            // ── App context actions (desktop actions & launch) ───────────
            Rectangle {
                visible: root.appActions.length > 0 || (root.appEntry?.toplevels?.length ?? 0) > 0
                Layout.fillWidth: true
                implicitHeight: desktopActionsCol.implicitHeight
                radius: 14
                color: Colors.surfaceContainerHigh
                clip: true

                ColumnLayout {
                    id: desktopActionsCol
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 0

                    // "New window" action if already running
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        color: "transparent"
                        visible: (root.appEntry?.toplevels?.length ?? 0) > 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol {
                                content: "add_to_photos"
                                iconSize: 16
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: "New window"
                                size: 12
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                if (root.desktopApp)
                                    ServiceApps.run(root.desktopApp);
                                else if (root.appEntry?.appId)
                                    ServiceApps.launch(root.appEntry.appId);
                                root.close();
                            }
                        }
                    }

                    // Desktop actions from .desktop file
                    Repeater {
                        model: root.appActions
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 38
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Image {
                                    visible: !!modelData.icon && modelData.icon.length > 0
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    source: modelData.icon ? IconUtil.getDesktopIconPath(modelData.icon, "image-missing") : ""
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                MaterialIconSymbol {
                                    visible: !modelData.icon || modelData.icon.length === 0
                                    content: "play_arrow"
                                    iconSize: 16
                                    customColor: Colors.outline
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: modelData.name
                                    size: 12
                                    elide: Text.ElideRight
                                }
                            }

                            RippleEffect {
                                anchors.fill: parent
                                onClicked: {
                                    ServiceApps.spawn(modelData.command, root.desktopApp?.workingDirectory ?? "");
                                    root.close();
                                }
                            }
                        }
                    }
                }
            }

            // ── System / Management actions group ────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: actionsCol.implicitHeight
                radius: 14
                color: Colors.surfaceContainerHigh
                clip: true

                ColumnLayout {
                    id: actionsCol
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 0

                    // Pin / Unpin
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol {
                                content: "push_pin"
                                iconSize: 16
                                fill: ServiceApps.isPinnedById(root.appEntry?.appId ?? "") ? 1 : 0
                                customColor: Colors.primary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: ServiceApps.isPinnedById(root.appEntry?.appId ?? "") ? "Unpin from dock" : "Pin to dock"
                                size: 12
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                ServiceApps.togglePinById(root.appEntry?.appId ?? "");
                                root.close();
                            }
                        }
                    }

                    // Close / Close all (only when running)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        color: "transparent"
                        visible: (root.appEntry?.toplevels?.length ?? 0) > 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialIconSymbol {
                                content: "cancel"
                                iconSize: 16
                                customColor: Colors.error
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: (root.appEntry?.toplevels?.length ?? 0) > 1 ? "Close all" : "Close"
                                size: 12
                                customColor: Colors.error
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            onClicked: {
                                for (const t of root.appEntry?.toplevels ?? [])
                                    t.close();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
