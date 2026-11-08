import qs.modules.components.Bar
import QtQuick
import qs.modules.services

BarButtonItem {
    id: root

    icon: ServiceScenes.restoring ? "hourglass_top" : "view_quilt"
    label: "Scenes"
    tip: ServiceScenes.restoring ? ServiceScenes.status : "Scenes"
    active: ServiceScenes.restoring || (!!root.host && root.host.panelKind === "scenes")
    onActivated: if (root.host)
        root.host.openPanel("scenes", root)
}
