import qs.modules.components.Bar
import QtQuick
import qs.modules.settings

BarButtonItem {
    icon: "content_paste"
    active: GlobalStates.clipboardOpen
    label: "Clipboard"
    onActivated: GlobalStates.clipboardOpen = !GlobalStates.clipboardOpen
}
