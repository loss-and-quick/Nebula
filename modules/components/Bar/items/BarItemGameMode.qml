import qs.modules.components.Bar
import QtQuick
import qs.modules.services

BarButtonItem {
    icon: "sports_esports"
    active: ServiceGameMode.active
    label: "Game mode"
    tip: ServiceGameMode.active ? "Game mode on" : "Game mode off"
    onActivated: ServiceGameMode.toggle()
}
