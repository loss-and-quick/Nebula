import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom

Rectangle {
    id: container
    color: Settings.layoutColor
    topLeftRadius: 20
    topRightRadius: 20

    signal closed

    readonly property int limit: 120
    readonly property real reach: 80
    onVisibleChanged: container.relayout()
    property string filter: "all"
    property int activeIndex: 0
    property bool confirmWipe: false

    readonly property var pins: SettingsConfig.general.clipboardPins ?? []
    readonly property var counts: {
        const c = { all: 0, text: 0, link: 0, image: 0 }
        for (const e of ServiceCliphist.entries) {
            c.all++
            c[ServiceCliphist.entryKind(e)]++
        }
        return c
    }
    readonly property var pinnedEntries: ServiceCliphist.entries.filter(e => container.pins.indexOf(ServiceCliphist.getEntryId(e)) >= 0)
    readonly property var visibleEntries: {
        const base = container.filter === "all" ? ServiceCliphist.filteredEntries
            : ServiceCliphist.filteredEntries.filter(e => ServiceCliphist.entryKind(e) === container.filter)
        return base.filter(e => container.pins.indexOf(ServiceCliphist.getEntryId(e)) < 0).slice(0, container.limit)
    }
    readonly property string activeEntry: container.visibleEntries[container.activeIndex] ?? ""
    readonly property int columns: Math.max(3, Math.floor((board.width + 12) / 232))
    readonly property real colWidth: (board.width - (container.columns - 1) * 12) / container.columns

    property var lanes: []
    property string lanesKey: ""

    function relayout() {
        const w = board.width
        if (w <= 0 || !container.visible)
            return
        const cols = Math.max(3, Math.floor((w + 12) / 232))
        const colW = (w - (cols - 1) * 12) / cols
        const list = container.visibleEntries
        const key = cols + "|" + colW + "|" + list.map(e => ServiceCliphist.getEntryId(e)).join(",")
        if (key === container.lanesKey)
            return
        const lanes = []
        const heights = []
        for (let i = 0; i < cols; i++) {
            lanes.push([])
            heights.push(0)
        }
        list.forEach((e, i) => {
            let k = 0
            for (let j = 1; j < heights.length; j++)
                if (heights[j] < heights[k]) k = j
            const kind = container.kindOf(e)
            const guess = container.estimate(e, colW, kind)
            lanes[k].push({ entry: e, index: i, kind: kind, guess: guess })
            heights[k] += guess + 12
        })
        container.lanesKey = key
        container.lanes = lanes
    }

    function kindOf(e) {
        const k = ServiceCliphist.entryKind(e)
        if (k !== "text") return k
        const t = ServiceCliphist.getEntryText(e).trim()
        if (/^(#[0-9a-f]{3}|#[0-9a-f]{6}|#[0-9a-f]{8}|rgba?\([^)]*\))$/i.test(t)) return "color"
        if (/^(~\/|\/)[^\s]*$/.test(t)) return "path"
        if (/[{};]|=>|^\s*(\$ |sudo |git |cd |ls |qs |hyprctl |nebula |pacman |yay |npm |python3? )/.test(t)) return "code"
        return "text"
    }

    function estimate(e, colW, kind) {
        const k = kind ?? container.kindOf(e)
        if (k === "image") {
            const d = ServiceCliphist.getImageDimensions(e)
            return d.width > 0 ? Math.min(220, Math.max(90, (colW ?? container.colWidth) * d.height / d.width)) + 44 : 160
        }
        if (k === "color") return 124
        const len = ServiceCliphist.getEntryText(e).length
        return 58 + Math.min(6, Math.ceil(len / 30)) * 18
    }

    function isPinned(e) {
        return container.pins.indexOf(ServiceCliphist.getEntryId(e)) >= 0
    }

    function togglePin(e) {
        const id = ServiceCliphist.getEntryId(e)
        if (!id) return
        const next = container.pins.filter(p => p !== id)
        if (next.length === container.pins.length) next.unshift(id)
        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { clipboardPins: next })
    }

    function copy(e) {
        if (!e) return
        ServiceCliphist.copy(e)
        container.closed()
    }

    function remove(e) {
        if (!e) return
        if (container.isPinned(e)) container.togglePin(e)
        ServiceCliphist.deleteEntry(e)
    }

    function select(i) {
        if (container.visibleEntries.length === 0) return
        container.activeIndex = Math.max(0, Math.min(i, container.visibleEntries.length - 1))
    }

    function cycleFilter(dir) {
        const vals = ["all", "text", "image", "link"]
        container.filter = vals[(vals.indexOf(container.filter) + dir + vals.length) % vals.length]
        container.activeIndex = 0
    }

    function colorOf(e) {
        const t = ServiceCliphist.getEntryText(e).trim()
        const m = /^rgba?\(([^)]*)\)$/i.exec(t)
        if (!m) return t
        const p = m[1].split(/[\s,\/]+/).filter(v => v !== "").map(parseFloat)
        const alpha = p[3] === undefined ? 1 : p[3] > 1 ? p[3] / 100 : p[3]
        return Qt.rgba((p[0] ?? 0) / 255, (p[1] ?? 0) / 255, (p[2] ?? 0) / 255, alpha)
    }

    function labelOf(e) {
        const k = container.kindOf(e)
        if (k === "link") return ServiceCliphist.getEntryText(e).trim().replace(/^https?:\/\//, "").split("/")[0]
        if (k === "image") {
            const info = ServiceCliphist.imageInfo(e)
            return info.width > 0 ? info.width + " × " + info.height + " · " + info.format.toUpperCase() : "Image"
        }
        return { text: "Text", code: "Code", path: "File", color: "Colour" }[k] ?? "Text"
    }

    function iconOf(k) {
        return { text: "notes", code: "code", path: "folder", color: "palette", link: "link", image: "image" }[k] ?? "notes"
    }

    onVisibleEntriesChanged: {
        if (container.activeIndex >= container.visibleEntries.length)
            container.activeIndex = Math.max(0, container.visibleEntries.length - 1)
        container.relayout()
    }

    Timer {
        id: wipeTimer
        interval: 3000
        onTriggered: container.confirmWipe = false
    }

    Component.onCompleted: {
        ServiceCliphist.updateSearch("")
        if (!GlobalStates.barEditMode) searchInput.forceActiveFocus()
    }

    component SmallButton: Rectangle {
        id: smb
        property string icon: ""
        property bool lit: false
        property color tint: Colors.surfaceText
        signal clicked
        implicitWidth: 30
        implicitHeight: 30
        radius: smbArea.pressed ? 9 : 15
        color: smb.lit ? Colors.primary : smbArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainer
        Behavior on radius { SpatialAnim { speed: "fast" } }
        MaterialIconSymbol {
            anchors.centerIn: parent
            content: smb.icon
            iconSize: 16
            customColor: smb.lit ? Colors.primaryText : smb.tint
        }
        CustomMouseArea {
            id: smbArea
            radius: smb.radius
            hoverEnabled: true
            onClicked: smb.clicked()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    MaterialIconSymbol {
                        content: "search"
                        iconSize: 18
                        customColor: Colors.primary
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            content: "Search " + ServiceCliphist.entries.length + " clips"
                            size: 14
                            customColor: Colors.outline
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            focus: !GlobalStates.barEditMode
                            selectByMouse: true
                            font.pixelSize: 14
                            font.weight: 600
                            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
                            color: Colors.surfaceText
                            selectionColor: Qt.alpha(Colors.primary, 0.35)

                            onTextChanged: {
                                ServiceCliphist.updateSearch(text)
                                container.activeIndex = 0
                            }
                            onAccepted: container.copy(container.activeEntry)

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                                    container.select(container.activeIndex + 1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                                    container.select(container.activeIndex - 1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Delete) {
                                    container.remove(container.activeEntry)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                    container.togglePin(container.activeEntry)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Tab) {
                                    container.cycleFilter(1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Backtab) {
                                    container.cycleFilter(-1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    if (searchInput.text !== "") searchInput.text = ""
                                    else container.closed()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            M3ButtonGroup {
                Layout.preferredHeight: 44
                model: [
                    { value: "all", label: "All " + container.counts.all },
                    { value: "text", label: "Text " + container.counts.text },
                    { value: "image", label: "Images " + container.counts.image },
                    { value: "link", label: "Links " + container.counts.link }
                ]
                activeCheck: v => container.filter === v
                onSegmentClicked: v => {
                    container.filter = v
                    container.activeIndex = 0
                }
                textSize: 12
            }

            SmallButton {
                implicitWidth: 44
                implicitHeight: 44
                radius: 22
                icon: "refresh"
                onClicked: ServiceCliphist.refresh()
            }

            SmallButton {
                implicitWidth: 44
                implicitHeight: 44
                radius: 22
                icon: container.confirmWipe ? "delete_forever" : "delete_sweep"
                tint: container.confirmWipe ? Colors.error : Colors.surfaceText
                onClicked: {
                    if (container.confirmWipe) {
                        container.confirmWipe = false
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, { clipboardPins: [] })
                        ServiceCliphist.wipe()
                    } else {
                        container.confirmWipe = true
                        wipeTimer.restart()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: container.pinnedEntries.length > 0
            spacing: 10

            MaterialIconSymbol {
                content: "push_pin"
                iconSize: 16
                customColor: Colors.primary
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: container.pinnedEntries

                delegate: Rectangle {
                    id: pinPill
                    required property string modelData
                    readonly property string kind: container.kindOf(pinPill.modelData)
                    width: Math.min(260, pinRow.implicitWidth + 24)
                    height: 40
                    radius: pinArea.pressed ? 12 : 20
                    color: pinArea.containsMouse ? Colors.secondaryContainer : Qt.alpha(Colors.secondaryContainer, 0.75)
                    Behavior on radius { SpatialAnim { speed: "fast" } }

                    RowLayout {
                        id: pinRow
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 14
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: pinPill.kind === "color" ? container.colorOf(pinPill.modelData) : Colors.surfaceContainerHighest
                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                visible: pinPill.kind !== "color"
                                content: container.iconOf(pinPill.kind)
                                iconSize: 15
                                customColor: Colors.primary
                            }
                        }

                        CustomText {
                            Layout.maximumWidth: 200
                            content: pinPill.kind === "image" ? container.labelOf(pinPill.modelData)
                                : ServiceCliphist.getEntryText(pinPill.modelData).trim().replace(/\s+/g, " ")
                            size: 13
                            weight: 500
                            elide: Text.ElideRight
                            family: pinPill.kind === "code" ? "monospace" : (SettingsConfig.general.defaultFont ?? "Rubik")
                            customColor: Colors.secondaryContainerText
                        }
                    }

                    CustomMouseArea {
                        id: pinArea
                        radius: pinPill.radius
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) container.togglePin(pinPill.modelData)
                            else container.copy(pinPill.modelData)
                        }
                    }
                }
            }
        }

        Item {
            id: board
            Layout.fillWidth: true
            Layout.fillHeight: true
            onWidthChanged: container.relayout()

            Flickable {
                id: flick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: lanesRow.implicitHeight + 8
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: lanesRow
                    spacing: 12

                    Repeater {
                        model: container.lanes

                        Column {
                            id: lane
                            required property var modelData
                            width: container.colWidth
                            spacing: 12

                            Repeater {
                                model: lane.modelData

                                Rectangle {
                                    id: card
                                    required property var modelData
                                    required property int index
                                    readonly property string entry: card.modelData.entry
                                    readonly property string kind: card.modelData.kind
                                    readonly property bool active: card.modelData.index === container.activeIndex
                                    readonly property bool placed: card.index === 0 || card.y > 0
                                    readonly property real guess: card.modelData.guess
                                    readonly property bool near: card.placed
                                        && card.y + 280 > flick.contentY - container.reach
                                        && card.y < flick.contentY + flick.height + container.reach
                                    property bool live: false
                                    onNearChanged: if (card.near) card.live = true
                                    Component.onCompleted: if (card.near) card.live = true

                                    width: lane.width
                                    height: bodyLoader.item ? bodyLoader.item.implicitHeight : card.guess
                                    radius: 20
                                    color: cardArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                                    clip: true
                                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                                    Loader {
                                        id: bodyLoader
                                        width: parent.width
                                        active: card.live

                                        sourceComponent: Column {
                                            Loader {
                                                active: card.kind === "image"
                                                visible: active
                                                width: parent.width
                                                height: active ? card.guess - 44 : 0
                                                sourceComponent: Rectangle {
                                                    color: Colors.surfaceContainer
                                                    ClipboardImage {
                                                        anchors.fill: parent
                                                        entry: card.entry
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                visible: card.kind === "color"
                                                width: parent.width
                                                height: visible ? 72 : 0
                                                color: card.kind === "color" ? container.colorOf(card.entry) : "transparent"
                                            }

                                            Item {
                                                width: parent.width
                                                height: inner.implicitHeight + 24

                                                ColumnLayout {
                                                    id: inner
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    anchors.margins: 12
                                                    anchors.leftMargin: 14
                                                    spacing: 6

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 6

                                                        MaterialIconSymbol {
                                                            content: container.iconOf(card.kind)
                                                            iconSize: 15
                                                            customColor: Colors.primary
                                                        }

                                                        CustomText {
                                                            Layout.fillWidth: true
                                                            content: container.labelOf(card.entry)
                                                            size: 11
                                                            weight: 500
                                                            elide: Text.ElideRight
                                                            customColor: Colors.outline
                                                        }
                                                    }

                                                    CustomText {
                                                        Layout.fillWidth: true
                                                        visible: card.kind !== "image"
                                                        content: ServiceCliphist.getEntryText(card.entry).trim()
                                                        size: card.kind === "code" ? 12 : 13
                                                        weight: card.kind === "color" ? 600 : 400
                                                        wrapMode: card.kind === "link" || card.kind === "path" ? Text.WrapAnywhere : Text.Wrap
                                                        maximumLineCount: 6
                                                        elide: Text.ElideRight
                                                        family: card.kind === "code" ? "monospace" : (SettingsConfig.general.defaultFont ?? "Rubik")
                                                        customColor: card.kind === "link" || card.kind === "path" ? Colors.secondary : Colors.surfaceText
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: card.active
                                        radius: parent.radius
                                        color: "transparent"
                                        border.width: 2
                                        border.color: Colors.primary
                                    }

                                    MouseArea {
                                        id: cardArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) container.togglePin(card.entry)
                                            else container.copy(card.entry)
                                        }
                                        onEntered: container.activeIndex = card.modelData.index
                                    }

                                    Loader {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        active: cardArea.containsMouse
                                        sourceComponent: Row {
                                            spacing: 4

                                            SmallButton {
                                                icon: "push_pin"
                                                onClicked: container.togglePin(card.entry)
                                            }

                                            SmallButton {
                                                icon: "delete"
                                                onClicked: container.remove(card.entry)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ScrollFade {
                flickable: flick
                color: container.color
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: container.visibleEntries.length === 0
                spacing: 8

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceCliphist.entries.length === 0 ? "content_paste" : "search_off"
                    iconSize: 32
                    customColor: Colors.outline
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceCliphist.entries.length === 0 ? "Nothing copied yet" : "No clips match"
                    size: 13
                    customColor: Colors.outline
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: [["Enter", "copy"], ["↑ ↓", "move"], ["Ctrl P", "pin"], ["Del", "remove"], ["Tab", "filter"]]

                RowLayout {
                    required property var modelData
                    spacing: 6

                    Rectangle {
                        implicitWidth: keyText.implicitWidth + 12
                        implicitHeight: 20
                        radius: 6
                        color: Colors.surfaceContainerHigh
                        CustomText {
                            id: keyText
                            anchors.centerIn: parent
                            content: parent.parent.modelData[0]
                            size: 11
                            weight: 600
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    CustomText {
                        content: parent.modelData[1]
                        size: 11
                        customColor: Colors.outline
                    }
                }
            }

            Item { Layout.fillWidth: true }

            CustomText {
                visible: ServiceCliphist.filteredEntries.length > container.limit
                content: "Showing the newest " + container.limit + " — search to find older clips"
                size: 11
                customColor: Colors.outline
            }
        }
    }
}
