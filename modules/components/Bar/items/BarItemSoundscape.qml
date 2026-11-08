import qs.modules.components.Bar
import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    icon: ServiceSoundscape.playing ? ServiceSoundscape.leadIcon : "graphic_eq"
    label: ServiceSoundscape.playing ? ServiceSoundscape.summary : "Soundscape"
    tip: ServiceSoundscape.playing ? "Soundscape: " + ServiceSoundscape.summary : "Soundscape"
    active: ServiceSoundscape.playing || (!!root.host && root.host.panelKind === "soundscape")
    onActivated: if (root.host)
        root.host.openPanel("soundscape", root)
}
