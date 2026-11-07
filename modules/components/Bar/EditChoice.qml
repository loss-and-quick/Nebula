pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.components.custom

ColumnLayout {
    id: group

    property var choices: []
    property var value: undefined
    property var isActive: null
    property int maxPerRow: 4
    property real minCell: 92
    property real rowHeight: 38
    signal picked(var value)

    readonly property int perRow: Math.max(1, Math.min(group.maxPerRow, group.choices.length,
                                                       Math.floor((group.width + 2) / group.minCell)))
    readonly property var rows: {
        const out = []
        const n = group.choices.length
        const lines = Math.ceil(n / group.perRow)
        const per = Math.ceil(n / Math.max(1, lines))
        for (let i = 0; i < n; i += per)
            out.push(group.choices.slice(i, i + per))
        return out
    }

    spacing: 4

    Repeater {
        model: group.rows

        delegate: M3ButtonGroup {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: group.rowHeight
            fillWidth: true
            iconSize: 16
            textSize: 12
            activeColor: Colors.secondaryContainer
            activeTextColor: Colors.secondaryContainerText
            inactiveColor: Colors.surfaceContainerHighest
            model: modelData
            activeCheck: function(v) { return group.isActive ? group.isActive(v) : group.value === v }
            onSegmentClicked: v => group.picked(v)
        }
    }
}
