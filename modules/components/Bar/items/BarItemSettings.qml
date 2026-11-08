import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    icon: "settings"
    active: GlobalStates.settingsOpen
    label: "Settings"
    onActivated: GlobalStates.settingsOpen = !GlobalStates.settingsOpen
}
