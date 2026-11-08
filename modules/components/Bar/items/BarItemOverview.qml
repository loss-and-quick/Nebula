import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    icon: "grid_view"
    active: GlobalStates.overviewOpen
    label: "Overview"
    onActivated: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
}
