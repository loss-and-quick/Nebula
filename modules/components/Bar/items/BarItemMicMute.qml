import qs.modules.components.Bar
import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    shown: BarLayout.opt(root.itemId, "onlyMuted") !== true || ServicePipewire.micMuted
    icon: ServicePipewire.micMuted ? "mic_off" : "mic"
    active: ServicePipewire.micMuted
    alert: ServicePipewire.micMuted
    label: ServicePipewire.micMuted ? "Mic off" : "Mic"
    tip: ServicePipewire.micMuted ? "Microphone muted" : "Microphone on"
    onActivated: ServicePipewire.toggleMicMute()
}
