import QtQuick
import qs.modules.utils
import qs.modules.components.custom

Rectangle {
    id: root

    property string label: ""
    property bool tonal: false

    implicitWidth: Math.max(20, keyText.implicitWidth + 12)
    implicitHeight: 20
    radius: 6
    color: root.tonal ? Qt.alpha(Colors.secondaryContainerText, 0.16) : Colors.surfaceContainerHighest

    CustomText {
        id: keyText
        anchors.centerIn: parent
        content: root.label
        size: 11
        weight: 600
        customColor: root.tonal ? Colors.secondaryContainerText : Colors.surfaceText
    }
}
