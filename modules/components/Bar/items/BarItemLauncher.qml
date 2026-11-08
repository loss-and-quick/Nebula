import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    icon: "apps"
    active: GlobalStates.appLauncherOpen
    label: "Apps"
    onActivated: GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
}
