import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    id: root

    readonly property bool dndOn: SettingsConfig.notifications?.doNotDisturb ?? false

    icon: root.dndOn ? "do_not_disturb_on" : "do_not_disturb_off"
    active: root.dndOn
    label: "Do not disturb"
    tip: root.dndOn ? "Do not disturb on" : "Do not disturb off"
    onActivated: SettingsConfig.notifications = Object.assign({}, SettingsConfig.notifications, {
        doNotDisturb: !root.dndOn
    })
}
