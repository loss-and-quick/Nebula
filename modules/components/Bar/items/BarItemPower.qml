import qs.modules.components.Bar
import QtQuick

BarButtonItem {
    id: root

    icon: "power_settings_new"
    label: "Power"
    tip: "Power menu"
    active: !!root.host && root.host.panelKind === "power"
    onActivated: if (root.host)
        root.host.openPanel("power", root)
}
