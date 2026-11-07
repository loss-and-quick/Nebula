import Quickshell
import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.components.custom

Rectangle {
    id: root
    anchors.fill: parent
    topLeftRadius: Appearance.radius.large
    topRightRadius: Appearance.radius.extraLarge
    color: Colors.surface
    anchors.bottom: parent.bottom

    Behavior on implicitHeight {
        NumberAnimation { duration: Appearance.duration.normal; easing.type: Easing.OutQuad }
    }

    Loader {
        id: colLoader
        active: root.visible
        visible: active
        anchors.fill: parent
        sourceComponent: WallpaperGallery {}
    }
}
