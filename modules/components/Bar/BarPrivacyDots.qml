import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.components.custom

Row {
    id: root

    property real iconPx: 15
    readonly property bool active: ServicePipewire.micInUse || ServicePipewire.screenShared
    readonly property string tip: {
        const parts = []
        if (ServicePipewire.micInUse)
            parts.push("Mic in use · " + ServicePipewire.micApps.join(", "))
        if (ServicePipewire.screenShared)
            parts.push("Screen is being shared")
        return parts.join("\n")
    }

    spacing: 4

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: ServicePipewire.micInUse
        spacing: 3

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Colors.tertiary
        }
        MaterialIconSymbol {
            anchors.verticalCenter: parent.verticalCenter
            content: "mic"
            iconSize: root.iconPx
            customColor: Colors.tertiary
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: ServicePipewire.screenShared
        spacing: 3

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Colors.primary
        }
        MaterialIconSymbol {
            anchors.verticalCenter: parent.verticalCenter
            content: "screen_share"
            iconSize: root.iconPx
            customColor: Colors.primary
        }
    }
}
