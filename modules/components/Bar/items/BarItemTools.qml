import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    icon: "screenshot_monitor"
    active: GlobalStates.toolsWidgetOpen
    label: "Tools"
    tip: "Screenshot and recording tools"
    onActivated: GlobalStates.toolsWidgetOpen = !GlobalStates.toolsWidgetOpen
}
