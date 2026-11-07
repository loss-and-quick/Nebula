import Quickshell
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

    property string filter: "all"
    property int activeIndex: 0
    property string previewText: ""
    property bool confirmWipe: false

    readonly property var counts: {
        const c = { all: 0, text: 0, link: 0, image: 0 }
        for (const e of ServiceCliphist.entries) {
            c.all++
            c[ServiceCliphist.entryKind(e)]++
        }
        return c
    }
    readonly property var visibleEntries: container.filter === "all" ? ServiceCliphist.filteredEntries
        : ServiceCliphist.filteredEntries.filter(e => ServiceCliphist.entryKind(e) === container.filter)
    readonly property string activeEntry: container.visibleEntries[container.activeIndex] ?? ""
    readonly property string activeKind: container.activeEntry !== "" ? ServiceCliphist.entryKind(container.activeEntry) : ""
    readonly property var imageInfo: container.activeKind === "image" ? ServiceCliphist.imageInfo(container.activeEntry) : null
    readonly property string shownText: container.previewText.length > 20000
        ? container.previewText.slice(0, 20000) + "\n…" : container.previewText
    readonly property bool looksLikeCode: container.shownText.indexOf("\n") >= 0
        && /[{};]|=>|^\s{2,}\S/m.test(container.shownText)
    readonly property string linkDomain: container.activeKind === "link"
        ? ServiceCliphist.getEntryText(container.activeEntry).trim().replace(/^https?:\/\//, "").split("/")[0] : ""

    readonly property var filters: [
        { value: "all",   label: "All " + container.counts.all },
        { value: "text",  label: "Text " + container.counts.text },
        { value: "image", label: "Images " + container.counts.image },
        { value: "link",  label: "Links " + container.counts.link }
    ]

    function select(i) {
        if (container.visibleEntries.length === 0)
            return
        container.activeIndex = Math.max(0, Math.min(i, container.visibleEntries.length - 1))
        list.positionViewAtIndex(container.activeIndex, ListView.Contain)
    }

    function focusSearch() {
        if (!GlobalStates.barEditMode) searchInput.forceActiveFocus()
    }

    function copyActive() {
        const e = container.activeEntry
        if (e === "")
            return
        ServiceCliphist.copy(e)
        container.closed()
    }

    function deleteActive() {
        if (container.activeEntry !== "")
            ServiceCliphist.deleteEntry(container.activeEntry)
    }

    function cycleFilter(dir) {
        const vals = container.filters.map(f => f.value)
        const k = vals.indexOf(container.filter)
        container.filter = vals[(k + dir + vals.length) % vals.length]
        container.activeIndex = 0
    }

    function loadPreview() {
        container.previewText = ""
        if (container.activeEntry === "" || container.activeKind === "image")
            return
        container.previewText = ServiceCliphist.getEntryText(container.activeEntry)
        ServiceCliphist.decodeText(container.activeEntry)
    }

    onActiveEntryChanged: previewTimer.restart()
    onVisibleEntriesChanged: {
        if (container.activeIndex >= container.visibleEntries.length)
            container.activeIndex = Math.max(0, container.visibleEntries.length - 1)
    }

    Timer {
        id: previewTimer
        interval: 60
        onTriggered: container.loadPreview()
    }

    Timer {
        id: wipeTimer
        interval: 3000
        onTriggered: container.confirmWipe = false
    }

    Connections {
        target: ServiceCliphist
        function onTextDecoded(entryId, text) {
            if (entryId === ServiceCliphist.getEntryId(container.activeEntry) && text !== "")
                container.previewText = text
        }
    }

    Component.onCompleted: {
        ServiceCliphist.updateSearch("")
        container.focusSearch()
        container.loadPreview()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 26
            color: Colors.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 18
                    color: Colors.surfaceContainerHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 6
                        spacing: 8

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
                                content: "Search clipboard"
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
                                onAccepted: container.copyActive()

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Down) {
                                        container.select(container.activeIndex + 1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        container.select(container.activeIndex - 1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Delete) {
                                        container.deleteActive()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Tab) {
                                        container.cycleFilter(1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Backtab) {
                                        container.cycleFilter(-1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        if (searchInput.text !== "")
                                            searchInput.text = ""
                                        else
                                            container.closed()
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            visible: searchInput.text.length > 0
                            color: clearSearch.containsMouse ? Colors.surfaceContainerHigh : "transparent"

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "close"
                                iconSize: 14
                                customColor: Colors.outline
                            }

                            MouseArea {
                                id: clearSearch
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }

                M3ButtonGroup {
                    model: container.filters
                    activeCheck: function(value) { return container.filter === value }
                    onSegmentClicked: function(value) {
                        container.filter = value
                        container.activeIndex = 0
                        container.focusSearch()
                    }
                }

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: refreshArea.containsMouse ? Colors.primaryContainer : "transparent"

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "cached"
                        iconSize: 18
                        customColor: refreshArea.containsMouse ? Colors.primaryContainerText : Colors.outline
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceCliphist.refresh()
                    }

                    CustomToolTip { visible: refreshArea.containsMouse; content: "Refresh" }
                }

                Rectangle {
                    implicitWidth: container.confirmWipe ? wipeRow.implicitWidth + 24 : 36
                    height: 36
                    radius: 18
                    color: container.confirmWipe ? Colors.error
                        : wipeArea.containsMouse ? Qt.alpha(Colors.error, 0.16) : "transparent"
                    Behavior on implicitWidth { SpatialAnim { speed: "fast" } }

                    Row {
                        id: wipeRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIconSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            content: "clear_all"
                            iconSize: 18
                            customColor: container.confirmWipe ? Colors.errorText
                                : wipeArea.containsMouse ? Colors.error : Colors.outline
                        }
                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: container.confirmWipe
                            content: "Clear all history"
                            size: 12
                            weight: 700
                            customColor: Colors.errorText
                        }
                    }

                    MouseArea {
                        id: wipeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (container.confirmWipe) {
                                container.confirmWipe = false
                                wipeTimer.stop()
                                ServiceCliphist.wipe()
                            } else {
                                container.confirmWipe = true
                                wipeTimer.restart()
                            }
                        }
                    }

                    CustomToolTip { visible: wipeArea.containsMouse && !container.confirmWipe; content: "Clear all" }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 440
                Layout.fillHeight: true
                radius: 22
                color: Colors.surfaceContainer
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel { values: container.visibleEntries }

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index

                        readonly property bool active: row.index === container.activeIndex
                        readonly property string kind: ServiceCliphist.entryKind(row.modelData)
                        readonly property var info: row.kind === "image" ? ServiceCliphist.imageInfo(row.modelData) : null

                        width: list.width
                        height: 52
                        radius: 16
                        color: row.active ? Colors.primaryContainer
                            : rowArea.containsMouse ? Qt.alpha(Colors.primary, 0.08) : "transparent"
                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 10
                                color: row.active ? Qt.alpha(Colors.primary, 0.22) : Qt.alpha(Colors.surfaceText, 0.06)

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: row.kind === "image" ? "image" : row.kind === "link" ? "link" : "notes"
                                    iconSize: 16
                                    customColor: row.active ? Colors.primaryContainerText : Colors.outline
                                }
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: row.kind === "image"
                                    ? "Image  " + row.info.width + " × " + row.info.height + "  " + row.info.format
                                    : ServiceCliphist.getEntryText(row.modelData).replace(/\s+/g, " ")
                                size: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                customColor: row.active ? Colors.primaryContainerText : Colors.surfaceText
                            }

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                opacity: rowArea.containsMouse || delArea.containsMouse ? 1 : 0
                                color: delArea.containsMouse ? Qt.alpha(Colors.error, 0.16) : "transparent"

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: "close"
                                    iconSize: 15
                                    customColor: delArea.containsMouse ? Colors.error
                                        : row.active ? Colors.primaryContainerText : Colors.outline
                                }

                                MouseArea {
                                    id: delArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceCliphist.deleteEntry(row.modelData)
                                }
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            anchors.rightMargin: 44
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                container.activeIndex = row.index
                                container.focusSearch()
                            }
                            onDoubleClicked: {
                                container.activeIndex = row.index
                                container.copyActive()
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    visible: container.visibleEntries.length === 0
                    spacing: 6

                    MaterialIconSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceCliphist.entries.length === 0 ? "content_paste" : "search_off"
                        iconSize: 32
                        customColor: Colors.outline
                    }
                    CustomText {
                        Layout.alignment: Qt.AlignHCenter
                        content: ServiceCliphist.entries.length === 0 ? "Clipboard is empty"
                            : searchInput.text !== "" ? "No matches for “" + searchInput.text + "”"
                            : "Nothing here yet"
                        size: 15
                        weight: 700
                    }
                    CustomText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        content: ServiceCliphist.entries.length === 0 ? "Copy something and it shows up here."
                            : "Try another search or filter."
                        size: 12
                        customColor: Colors.outline
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 22
                color: Colors.surfaceContainer
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14
                    visible: container.activeEntry !== ""

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialIconSymbol {
                            content: container.activeKind === "image" ? "image"
                                : container.activeKind === "link" ? "link"
                                : container.looksLikeCode ? "code" : "notes"
                            iconSize: 18
                            customColor: Colors.primary
                        }
                        CustomText {
                            content: container.activeKind === "image" ? "Image"
                                : container.activeKind === "link" ? "Link"
                                : container.looksLikeCode ? "Code" : "Text"
                            size: 14
                            weight: 700
                            customColor: Colors.primary
                        }
                        Item { Layout.fillWidth: true }

                        Repeater {
                            model: {
                                if (container.activeKind === "image" && container.imageInfo)
                                    return [container.imageInfo.width + " × " + container.imageInfo.height,
                                            container.imageInfo.format, container.imageInfo.size]
                                if (container.activeKind === "link")
                                    return [container.linkDomain]
                                const t = container.previewText
                                const words = t.trim() === "" ? 0 : t.trim().split(/\s+/).length
                                const lines = t === "" ? 0 : t.split("\n").length
                                return [t.length + " characters", words + (words === 1 ? " word" : " words"),
                                        lines + (lines === 1 ? " line" : " lines")]
                            }

                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: factText.implicitWidth + 16
                                implicitHeight: 24
                                radius: 12
                                color: Colors.surfaceContainerHigh

                                CustomText {
                                    id: factText
                                    anchors.centerIn: parent
                                    content: String(parent.modelData)
                                    size: 11
                                    customColor: Colors.surfaceText
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: textFlick
                            anchors.fill: parent
                            visible: container.activeKind === "text"
                            clip: true
                            contentWidth: width
                            contentHeight: previewEdit.contentHeight
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: previewEdit
                                width: textFlick.width
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                textFormat: TextEdit.PlainText
                                text: container.shownText
                                color: Colors.surfaceText
                                selectionColor: Qt.alpha(Colors.primary, 0.35)
                                font.family: container.looksLikeCode
                                    ? ((SettingsConfig.ai ?? {}).codeFont ?? "monospace")
                                    : (SettingsConfig.general.defaultFont ?? "Rubik")
                                font.pixelSize: container.looksLikeCode ? 14 : 16
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: container.activeKind === "link"
                            spacing: 8

                            CustomText {
                                Layout.fillWidth: true
                                content: container.linkDomain
                                size: 28
                                weight: 700
                                elide: Text.ElideRight
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: container.activeKind === "link" ? ServiceCliphist.getEntryText(container.activeEntry).trim() : ""
                                size: 14
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                customColor: Colors.primary
                            }
                        }

                        Repeater {
                            model: container.activeKind === "image" ? [container.activeEntry] : []
                            delegate: ClipboardImage {
                                required property var modelData
                                anchors.fill: parent
                                entry: modelData
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CustomText {
                            Layout.fillWidth: true
                            content: "Enter copies, Delete removes, Tab switches filter"
                            size: 11
                            customColor: Colors.outline
                            elide: Text.ElideRight
                        }
                        M3Button {
                            variant: "text"
                            icon: "delete"
                            label: "Delete"
                            onClicked: container.deleteActive()
                        }
                        M3Button {
                            visible: container.activeKind === "link"
                            variant: "tonal"
                            icon: "open_in_new"
                            label: "Open"
                            onClicked: Qt.openUrlExternally(ServiceCliphist.getEntryText(container.activeEntry).trim())
                        }
                        M3Button {
                            icon: "content_copy"
                            label: "Copy"
                            onClicked: container.copyActive()
                        }
                    }
                }

                CustomText {
                    anchors.centerIn: parent
                    visible: container.activeEntry === ""
                    content: "Select an entry to preview it"
                    size: 13
                    customColor: Colors.outline
                }
            }
        }
    }
}
