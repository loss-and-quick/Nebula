import QtQuick
import qs.modules.components.custom

StageRow {
    id: row

    property bool checked: false
    signal toggled(bool on)

    clickable: true
    onClicked: row.toggled(!row.checked)

    CustomToogle {
        isToggleOn: row.checked
        onToggled: state => row.toggled(state)
    }
}
