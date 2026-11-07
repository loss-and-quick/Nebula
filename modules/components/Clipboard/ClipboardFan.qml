import Quickshell
import Quickshell.Io
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
    property bool cropMode: false
    property string toast: ""

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
    readonly property string activeKind: container.kindOf(container.activeEntry, container.previewText)
    readonly property var imageInfo: container.activeKind === "image" ? ServiceCliphist.imageInfo(container.activeEntry) : null
    readonly property string shownText: container.previewText.length > 20000
        ? container.previewText.slice(0, 20000) + "\n…" : container.previewText
    readonly property string linkUrl: container.activeKind === "link" ? ServiceCliphist.getEntryText(container.activeEntry).trim() : ""
    readonly property string linkDomain: container.linkUrl.replace(/^https?:\/\//, "").split("/")[0]
    readonly property var upNext: container.visibleEntries.slice(container.activeIndex + 1, container.activeIndex + 40)

    readonly property var filters: [
        { value: "all",   label: "All",    icon: "stacks", n: container.counts.all },
        { value: "text",  label: "Text",   icon: "notes",  n: container.counts.text },
        { value: "image", label: "Images", icon: "image",  n: container.counts.image },
        { value: "link",  label: "Links",  icon: "link",   n: container.counts.link }
    ]

    function isColor(t) {
        const s = (t ?? "").trim()
        return /^#([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s)
            || /^(rgb|rgba|hsl|hsla)\(\s*[\d.]+%?\s*,?\s*[\d.]+%?\s*,?\s*[\d.]+%?\s*([,/]\s*[\d.]+%?\s*)?\)$/i.test(s)
    }

    function looksLikeCode(t) {
        return (t ?? "").indexOf("\n") >= 0 && /[{};]|=>|^\s{2,}\S/m.test(t)
    }

    function kindOf(entry, full) {
        if (entry === "") return ""
        const k = ServiceCliphist.entryKind(entry)
        if (k !== "text") return k
        const t = full !== undefined && full !== "" ? full : ServiceCliphist.getEntryText(entry)
        if (container.isColor(t)) return "color"
        if (container.looksLikeCode(t)) return "code"
        return "text"
    }

    function kindIcon(k) {
        return k === "image" ? "image" : k === "link" ? "link" : k === "color" ? "palette" : k === "code" ? "code" : "notes"
    }

    function kindLabel(k) {
        return k === "image" ? "Image" : k === "link" ? "Link" : k === "color" ? "Colour" : k === "code" ? "Code" : "Text"
    }

    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function select(i) {
        if (container.visibleEntries.length === 0)
            return
        const next = Math.max(0, Math.min(i, container.visibleEntries.length - 1))
        if (next === container.activeIndex)
            return
        const dir = next > container.activeIndex ? 1 : -1
        container.cropMode = false
        container.activeIndex = next
        upList.positionViewAtBeginning()
        dealAnim.stop()
        front.dealX = dir > 0 ? 34 : -120
        front.dealRot = dir > 0 ? -5 : 7
        front.dealOp = 0.2
        dealAnim.start()
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
        if (container.activeEntry === "" || ServiceCliphist.entryIsImage(container.activeEntry))
            return
        container.previewText = ServiceCliphist.getEntryText(container.activeEntry)
        ServiceCliphist.decodeText(container.activeEntry)
    }

    function say(text) {
        container.toast = text
        toastTimer.restart()
    }

    function runOcr() {
        const img = body.img
        if (!img || !img.ready || ocrProc.running)
            return
        ocrProc.command = ["sh", "-c", "tesseract " + container.shq(img.path) + " - --psm 6 2>/dev/null"]
        ocrProc.running = true
    }

    function copyCrop() {
        const img = body.img
        if (!img || !img.ready || sel.width < 4 || sel.height < 4)
            return
        const p = img.painted
        const k = img.dims.width / p.width
        const x = Math.round((sel.x - p.x) * k)
        const y = Math.round((sel.y - p.y) * k)
        const w = Math.round(sel.width * k)
        const h = Math.round(sel.height * k)
        cropProc.command = ["sh", "-c", "magick " + container.shq(img.path) + " -crop " + w + "x" + h + "+" + x + "+" + y
            + " +repage png:- | wl-copy -t image/png"]
        cropProc.running = true
    }

    function colorFacts(t) {
        const c = Qt.color(t.trim())
        const r = Math.round(c.r * 255), g = Math.round(c.g * 255), b = Math.round(c.b * 255)
        const hex = "#" + [r, g, b].map(v => v.toString(16).padStart(2, "0")).join("").toUpperCase()
        const h = Math.round(Math.max(0, c.hslHue) * 360), s = Math.round(c.hslSaturation * 100), l = Math.round(c.hslLightness * 100)
        return [["HEX", hex], ["RGB", r + " " + g + " " + b], ["HSL", h + "° " + s + "% " + l + "%"]]
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
        id: toastTimer
        interval: 2200
        onTriggered: container.toast = ""
    }

    Process {
        id: ocrProc
        stdout: StdioCollector { id: ocrOut }
        onExited: {
            const t = ocrOut.text.replace(/\n{3,}/g, "\n\n").trim()
            if (t === "") {
                container.say("No text found in this image")
                return
            }
            Quickshell.execDetached(["wl-copy", "--", t])
            const words = t.split(/\s+/).length
            container.say("Copied " + words + (words === 1 ? " word" : " words") + " from the image")
        }
    }

    Process {
        id: cropProc
        onExited: exitCode => {
            container.cropMode = false
            container.say(exitCode === 0 ? "Cropped image copied" : "Couldn’t crop this image")
            if (exitCode === 0) Qt.callLater(ServiceCliphist.refresh)
        }
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

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 24

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real cardW: Math.min(stage.width - 80, 660)
            readonly property real cardH: stage.height - 14

            Repeater {
                model: Math.min(4, Math.max(0, container.visibleEntries.length - container.activeIndex - 1))
                delegate: Rectangle {
                    id: back
                    required property int index
                    readonly property int k: back.index + 1
                    z: -back.k
                    x: 64 - back.k * 12
                    y: 8
                    width: stage.cardW
                    height: stage.cardH
                    radius: 26
                    color: Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.surface, back.k * 0.16))
                    border.width: 1
                    border.color: Qt.alpha(Colors.outlineVariant, 0.5)
                    transform: Rotation {
                        origin.x: back.width * 0.3
                        origin.y: back.height * 1.15
                        angle: -back.k * 3.6
                        Behavior on angle { SpatialAnim { speed: "fast" } }
                    }
                    Behavior on x { SpatialAnim { speed: "fast" } }
                }
            }

            Rectangle {
                id: front
                property real dealX: 0
                property real dealRot: 0
                property real dealOp: 1

                x: 64
                y: 8
                width: stage.cardW
                height: stage.cardH
                radius: 26
                color: Colors.surfaceContainerHighest
                visible: container.activeEntry !== ""
                opacity: front.dealOp
                transform: [
                    Rotation { origin.x: front.width * 0.3; origin.y: front.height * 1.15; angle: front.dealRot },
                    Translate { x: front.dealX }
                ]

                ParallelAnimation {
                    id: dealAnim
                    NumberAnimation {
                        target: front; property: "dealX"; to: 0
                        duration: M3Motion.spatialDuration("default")
                        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
                    }
                    NumberAnimation {
                        target: front; property: "dealRot"; to: 0
                        duration: M3Motion.spatialDuration("default")
                        easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.spatialCurve("default")
                    }
                    NumberAnimation {
                        target: front; property: "dealOp"; to: 1
                        duration: M3Motion.effectsDuration("default")
                        easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.effects.curve
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            implicitWidth: badgeRow.implicitWidth + 22
                            implicitHeight: 28
                            radius: 14
                            color: Colors.tertiaryContainer

                            Row {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIconSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: container.kindIcon(container.activeKind)
                                    iconSize: 16
                                    customColor: Colors.tertiaryContainerText
                                }
                                CustomText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    content: container.kindLabel(container.activeKind)
                                    size: 12
                                    weight: 600
                                    customColor: Colors.tertiaryContainerText
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        CustomText {
                            content: (container.activeIndex + 1) + " of " + container.visibleEntries.length
                            size: 12
                            family: (SettingsConfig.ai ?? {}).codeFont ?? "monospace"
                            customColor: Colors.outline
                        }
                    }

                    Item {
                        id: body
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        property Item img: null

                        Repeater {
                            model: container.activeKind === "image" ? [container.activeEntry] : []
                            delegate: ClipboardImage {
                                id: clipImg
                                required property var modelData
                                width: body.width
                                height: body.height
                                entry: modelData
                                Component.onCompleted: body.img = clipImg
                                Component.onDestruction: if (body.img === clipImg) body.img = null
                            }
                        }

                        Flickable {
                            id: textFlick
                            anchors.fill: parent
                            visible: container.activeKind === "text" || container.activeKind === "code"
                            clip: true
                            contentWidth: width
                            contentHeight: previewEdit.contentHeight
                            topMargin: container.activeKind === "text" ? Math.max(0, (textFlick.height - previewEdit.contentHeight) / 2) : 0
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: previewEdit
                                width: textFlick.width
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                textFormat: TextEdit.PlainText
                                text: container.shownText
                                color: container.activeKind === "code" ? Colors.tertiary : Colors.surfaceText
                                selectionColor: Qt.alpha(Colors.primary, 0.35)
                                font.family: container.activeKind === "code"
                                    ? ((SettingsConfig.ai ?? {}).codeFont ?? "monospace")
                                    : "Noto Serif Display"
                                font.pixelSize: container.activeKind === "code" ? 15
                                    : container.shownText.length < 90 ? 30 : container.shownText.length < 400 ? 20 : 16
                            }
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: container.activeKind === "link"
                            spacing: 10

                            MaterialIconSymbol {
                                content: "public"
                                iconSize: 34
                                customColor: Colors.tertiary
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: container.linkDomain
                                size: 34
                                weight: 700
                                family: "Noto Serif Display"
                                elide: Text.ElideRight
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: container.linkUrl
                                size: 14
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                customColor: Colors.primary
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: container.activeKind === "color"
                            spacing: 20

                            Rectangle {
                                Layout.fillHeight: true
                                Layout.preferredWidth: height
                                radius: 22
                                color: container.activeKind === "color" ? Qt.color(container.shownText.trim()) : "transparent"
                                border.width: 1
                                border.color: Qt.alpha(Colors.surfaceText, 0.12)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Repeater {
                                    model: container.activeKind === "color" ? container.colorFacts(container.shownText) : []
                                    delegate: RowLayout {
                                        required property var modelData
                                        spacing: 12
                                        CustomText {
                                            Layout.preferredWidth: 40
                                            content: modelData[0]
                                            size: 11
                                            weight: 700
                                            customColor: Colors.outline
                                        }
                                        CustomText {
                                            content: modelData[1]
                                            size: 20
                                            family: (SettingsConfig.ai ?? {}).codeFont ?? "monospace"
                                        }
                                        Rectangle {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            radius: 14
                                            color: factArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                                            MaterialIconSymbol {
                                                anchors.centerIn: parent
                                                content: "content_copy"
                                                iconSize: 15
                                                customColor: Colors.outline
                                            }
                                            MouseArea {
                                                id: factArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.clipboardText = modelData[1]
                                                    container.say("Copied " + modelData[1])
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: cropLayer
                            anchors.fill: parent
                            visible: container.cropMode && container.activeKind === "image"
                            readonly property rect p: body.img ? body.img.painted : Qt.rect(0, 0, 0, 0)

                            Rectangle { x: cropLayer.p.x; y: cropLayer.p.y; width: cropLayer.p.width; height: sel.y - cropLayer.p.y; color: Qt.alpha(Colors.scrim, 0.55) }
                            Rectangle { x: cropLayer.p.x; y: sel.y + sel.height; width: cropLayer.p.width; height: cropLayer.p.y + cropLayer.p.height - sel.y - sel.height; color: Qt.alpha(Colors.scrim, 0.55) }
                            Rectangle { x: cropLayer.p.x; y: sel.y; width: sel.x - cropLayer.p.x; height: sel.height; color: Qt.alpha(Colors.scrim, 0.55) }
                            Rectangle { x: sel.x + sel.width; y: sel.y; width: cropLayer.p.x + cropLayer.p.width - sel.x - sel.width; height: sel.height; color: Qt.alpha(Colors.scrim, 0.55) }

                            Rectangle {
                                id: sel
                                color: "transparent"
                                border.width: 2
                                border.color: Colors.primary
                            }

                            MouseArea {
                                x: cropLayer.p.x
                                y: cropLayer.p.y
                                width: cropLayer.p.width
                                height: cropLayer.p.height
                                cursorShape: Qt.CrossCursor
                                property point start
                                function clampPt(mx, my) {
                                    return Qt.point(cropLayer.p.x + Math.max(0, Math.min(width, mx)), cropLayer.p.y + Math.max(0, Math.min(height, my)))
                                }
                                onPressed: mouse => {
                                    start = clampPt(mouse.x, mouse.y)
                                    sel.x = start.x; sel.y = start.y; sel.width = 0; sel.height = 0
                                }
                                onPositionChanged: mouse => {
                                    const q = clampPt(mouse.x, mouse.y)
                                    sel.x = Math.min(start.x, q.x); sel.y = Math.min(start.y, q.y)
                                    sel.width = Math.abs(q.x - start.x); sel.height = Math.abs(q.y - start.y)
                                }
                            }

                            Connections {
                                target: container
                                function onCropModeChanged() {
                                    if (!container.cropMode) return
                                    const p = cropLayer.p
                                    sel.x = p.x + p.width * 0.1; sel.y = p.y + p.height * 0.1
                                    sel.width = p.width * 0.8; sel.height = p.height * 0.8
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            CustomText {
                                Layout.fillWidth: true
                                content: container.activeKind === "image" ? (container.cropMode ? "Drag to choose the part to keep" : "Image")
                                    : container.activeKind === "link" ? container.linkDomain
                                    : container.activeKind === "color" ? container.shownText.trim()
                                    : container.activeKind === "code" ? (container.shownText.split("\n").map(l => l.trim()).find(l => l.length > 3) ?? "Code")
                                    : container.shownText.trim().split("\n")[0]
                                size: container.activeKind === "code" || container.activeKind === "color" ? 16 : 18
                                weight: 600
                                family: container.activeKind === "code" || container.activeKind === "color"
                                    ? ((SettingsConfig.ai ?? {}).codeFont ?? "monospace") : "Noto Serif Display"
                                elide: Text.ElideRight
                            }
                            CustomText {
                                Layout.fillWidth: true
                                content: {
                                    if (container.activeKind === "image" && container.imageInfo)
                                        return container.imageInfo.width + " × " + container.imageInfo.height + " · "
                                            + container.imageInfo.format.toUpperCase() + " · " + container.imageInfo.size
                                    if (container.activeKind === "link") return container.linkUrl
                                    const t = container.previewText
                                    const words = t.trim() === "" ? 0 : t.trim().split(/\s+/).length
                                    const lines = t === "" ? 0 : t.split("\n").length
                                    return t.length + " characters · " + words + (words === 1 ? " word" : " words")
                                        + " · " + lines + (lines === 1 ? " line" : " lines")
                                }
                                size: 12
                                elide: Text.ElideRight
                                customColor: Colors.outline
                            }
                        }

                        Rectangle {
                            visible: container.toast !== ""
                            implicitWidth: toastText.implicitWidth + 28
                            implicitHeight: 32
                            radius: 16
                            color: Colors.inverseSurface
                            CustomText {
                                id: toastText
                                anchors.centerIn: parent
                                content: container.toast
                                size: 12
                                weight: 600
                                customColor: Colors.inverseSurfaceText
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: 320
                visible: container.activeEntry === ""
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
                        : searchInput.text !== "" ? "No matches for “" + searchInput.text + "”" : "Nothing here yet"
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

        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.maximumWidth: 380
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 23
                color: Colors.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 10

                    MaterialIconSymbol {
                        content: "search"
                        iconSize: 19
                        customColor: Colors.primary
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        CustomText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            content: "Search " + container.counts.all + " clips"
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
                                container.cropMode = false
                            }
                            onAccepted: container.cropMode ? container.copyCrop() : container.copyActive()

                            Keys.onPressed: event => {
                                const k = event.key
                                if (k === Qt.Key_Right || k === Qt.Key_Down) {
                                    if (k === Qt.Key_Right && searchInput.cursorPosition < searchInput.text.length) return
                                    container.select(container.activeIndex + 1)
                                    event.accepted = true
                                } else if (k === Qt.Key_Left || k === Qt.Key_Up) {
                                    if (k === Qt.Key_Left && searchInput.cursorPosition > 0) return
                                    container.select(container.activeIndex - 1)
                                    event.accepted = true
                                } else if (k === Qt.Key_Delete) {
                                    container.deleteActive()
                                    event.accepted = true
                                } else if (k === Qt.Key_Tab) {
                                    container.cycleFilter(1)
                                    event.accepted = true
                                } else if (k === Qt.Key_Backtab) {
                                    container.cycleFilter(-1)
                                    event.accepted = true
                                } else if (k === Qt.Key_Escape) {
                                    if (container.cropMode) container.cropMode = false
                                    else if (searchInput.text !== "") searchInput.text = ""
                                    else container.closed()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        visible: searchInput.text.length > 0
                        color: clearArea.containsMouse ? Colors.surfaceContainerHighest : "transparent"
                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "close"
                            iconSize: 14
                            customColor: Colors.outline
                        }
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: container.filters
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool on: container.filter === chip.modelData.value
                        implicitWidth: chipRow.implicitWidth + 24
                        implicitHeight: 32
                        radius: 16
                        color: chip.on ? Colors.secondaryContainer
                            : chipArea.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                        border.width: chip.on ? 0 : 1
                        border.color: Colors.outlineVariant

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: chip.modelData.icon
                                iconSize: 15
                                customColor: chip.on ? Colors.secondaryContainerText : Colors.outline
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: chip.modelData.label + "  " + chip.modelData.n
                                size: 12
                                weight: 500
                                customColor: chip.on ? Colors.secondaryContainerText : Colors.surfaceText
                            }
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                container.filter = chip.modelData.value
                                container.activeIndex = 0
                                container.focusSearch()
                            }
                        }
                    }
                }
            }

            CustomText {
                Layout.leftMargin: 6
                Layout.topMargin: 4
                visible: container.upNext.length > 0
                content: "UP NEXT"
                size: 11
                weight: 600
                font.letterSpacing: 1.2
                customColor: Colors.primary
            }

            ListView {
                id: upList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: container.upNext }

                delegate: Rectangle {
                    id: nextRow
                    required property var modelData
                    required property int index
                    readonly property string kind: container.kindOf(nextRow.modelData)
                    readonly property var info: nextRow.kind === "image" ? ServiceCliphist.imageInfo(nextRow.modelData) : null

                    width: upList.width
                    height: 50
                    radius: 16
                    color: nextArea.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12

                        MaterialIconSymbol {
                            content: container.kindIcon(nextRow.kind)
                            iconSize: 18
                            customColor: Colors.outline
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            CustomText {
                                Layout.fillWidth: true
                                content: nextRow.kind === "image"
                                    ? "Image " + nextRow.info.width + " × " + nextRow.info.height
                                    : ServiceCliphist.getEntryText(nextRow.modelData).replace(/\s+/g, " ")
                                size: 13
                                weight: 500
                                elide: Text.ElideRight
                            }
                            CustomText {
                                content: container.kindLabel(nextRow.kind)
                                size: 11
                                customColor: Colors.outline
                            }
                        }
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            container.select(container.activeIndex + 1 + nextRow.index)
                            container.focusSearch()
                        }
                        onDoubleClicked: {
                            container.select(container.activeIndex + 1 + nextRow.index)
                            container.copyActive()
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                visible: container.activeEntry !== ""

                M3Button {
                    icon: container.cropMode ? "check" : "content_copy"
                    label: container.cropMode ? "Copy crop" : "Copy"
                    onClicked: container.cropMode ? container.copyCrop() : container.copyActive()
                }
                M3Button {
                    visible: container.activeKind === "image"
                    variant: container.cropMode ? "text" : "tonal"
                    icon: container.cropMode ? "close" : "crop"
                    label: container.cropMode ? "Cancel" : "Crop"
                    onClicked: {
                        container.cropMode = !container.cropMode
                        container.focusSearch()
                    }
                }
                M3Button {
                    visible: container.activeKind === "image" && !container.cropMode
                    variant: "tonal"
                    icon: ocrProc.running ? "hourglass_top" : "text_fields"
                    label: ocrProc.running ? "Reading…" : "Copy text"
                    onClicked: container.runOcr()
                }
                M3Button {
                    visible: container.activeKind === "link"
                    variant: "tonal"
                    icon: "open_in_new"
                    label: "Open"
                    onClicked: Qt.openUrlExternally(container.linkUrl)
                }
                M3Button {
                    visible: !container.cropMode
                    variant: "text"
                    icon: "delete"
                    label: "Delete"
                    onClicked: container.deleteActive()
                }
            }

            CustomText {
                Layout.fillWidth: true
                content: "←  → deal the next card · Enter copies · Tab filters · Delete discards"
                size: 11
                elide: Text.ElideRight
                customColor: Colors.outline
            }
        }
    }
}
