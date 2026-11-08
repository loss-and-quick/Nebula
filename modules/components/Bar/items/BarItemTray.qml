import "../panels"
import qs.modules.components.Bar
import QtQuick
import qs.modules.utils
import qs.modules.services

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 30)
    readonly property bool shown: ServiceSystemTray.active
    readonly property int limit: BarLayout.opt(root.itemId, "visible") ?? 3
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true

    implicitWidth: root.vertical ? root.plate : loader.item ? loader.item.implicitWidth : 0
    implicitHeight: root.vertical ? (loader.item ? loader.item.implicitHeight : 0) : root.plate

    Loader {
        id: loader
        active: root.shown
        anchors.centerIn: parent
        sourceComponent: SystemTray {
            columns: root.vertical ? 1 : 0
            iconPx: root.iconPx
            plate: root.plate
            limit: root.limit
            onOverflowHovered: src => {
                if (root.host && root.host.openTrayOverflow)
                    root.host.openTrayOverflow(src, root.limit, false);
            }
            onOverflowClicked: src => {
                if (root.host && root.host.openTrayOverflow)
                    root.host.openTrayOverflow(src, root.limit, true);
            }
            onMenuRequested: (it, src) => {
                if (root.host && root.host.openTrayMenu)
                    root.host.openTrayMenu(it, src);
            }
        }
    }
}
