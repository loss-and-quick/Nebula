import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    icon: "wallpaper"
    active: GlobalStates.wallpaperOpen
    label: "Wallpaper"
    onActivated: GlobalStates.wallpaperOpen = !GlobalStates.wallpaperOpen
}
