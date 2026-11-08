import Quickshell
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom
import "BarOps.js" as BarOps

Item {
    id: blockLayout

    required property Item block
    property Item revealer: null

    y: (block.far ? -block.lineUp : block.lineUp) / 2
    width: block.width
    height: block.barH
    clip: !block.split

    ListModel {
        id: itemModel
    }
    readonly property alias itemModel: itemModel
    readonly property alias rep: rep

    property var itemLeaving: ({})
    property int slotRev: 0

    readonly property var itemIds: block.itemIds

    onItemIdsChanged: {
        BarLayout.syncAnimated(itemModel, blockLayout.itemIds, "itemId", blockLayout.itemLeaving);
        blockLayout.slotRev++;
    }

    Component.onCompleted: {
        BarLayout.syncModel(itemModel, blockLayout.itemIds, "itemId", blockLayout.itemLeaving);
        blockLayout.slotRev++;
    }

    function slotGone(id) {
        BarLayout.dropLeaving(itemModel, blockLayout.itemIds, "itemId", blockLayout.itemLeaving, id);
        blockLayout.slotRev++;
    }

    readonly property real gap: block.split ? Math.max(6, block.edgeCfg.itemGap) : block.edgeCfg.itemGap
    readonly property real basePad: block.anchorSide === "center" ? 15 : 10
    property var edgeL: null
    property var edgeR: null
    readonly property var corners: block.frame && block.frame.cornerOf ? block.frame.cornerOf(block.blockId, block.frame.sdfField) : null
    readonly property real pad: blockLayout.endPad(blockLayout.edgeL, blockLayout.corners ? blockLayout.corners.l : 0)
    readonly property real padR: blockLayout.endPad(blockLayout.edgeR, blockLayout.corners ? blockLayout.corners.r : 0)

    function endPad(edge, corner) {
        if (block.split)
            return 0;
        if (!edge)
            return blockLayout.basePad;
        const fit = side => Math.max(0, Math.min(blockLayout.basePad, side - edge.off)) - blockLayout.basePad;
        const stepW = corner > 0.5 ? block.stepT : 0;
        return blockLayout.basePad + fit(edge.gap) * block.pillT + fit(Math.max(edge.gap, corner - edge.r)) * stepW;
    }

    function edgeShape(slot, fromRight) {
        const top = slot.loaderItem;
        if (!top)
            return null;
        let found = null;
        let nearest = Infinity;
        const walk = (it, depth) => {
            if (!it || !it.visible || depth > 12)
                return;
            if (it.radius !== undefined && it.color !== undefined && it.height >= block.barH * 0.45 && it.width >= it.height * 0.6) {
                const p = it.mapToItem(slot, 0, 0);
                const off = fromRight ? slot.width - (p.x + it.width) : p.x;
                if (off < nearest && off < blockLayout.basePad) {
                    nearest = off;
                    found = {
                        gap: (block.barH - it.height) / 2,
                        off: off,
                        r: Math.min(it.radius, it.width / 2, it.height / 2)
                    };
                }
            }
            for (const c of it.children)
                walk(c, depth + 1);
        };
        walk(top, 0);
        return found;
    }

    function measureEdges() {
        if (typeof blockLayout.edgeShape !== "function")
            return;
        let first = null;
        let last = null;
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (!s || s.leaving || !s.itemShown)
                continue;
            if (!first)
                first = s;
            last = s;
        }
        blockLayout.edgeL = first ? blockLayout.edgeShape(first, false) : null;
        blockLayout.edgeR = last ? blockLayout.edgeShape(last, true) : null;
    }

    onSlotLayoutChanged: blockLayout.measureEdges()
    onShownCountChanged: blockLayout.measureEdges()

    Connections {
        target: block
        function onBarHChanged() {
            blockLayout.measureEdges();
        }
    }

    readonly property var slotLayout: {
        blockLayout.slotRev;
        const xs = [];
        let x = 0;
        let before = 0;
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k);
            const pc = o ? Math.min(1, o.pc) : 0;
            x += blockLayout.gap * Math.min(pc, before);
            xs.push(x);
            x += o ? o.width : 0;
            before = Math.max(before, pc);
        }
        return {
            xs: xs,
            total: x
        };
    }

    readonly property int shownCount: {
        let n = 0;
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && !s.leaving && s.itemShown)
                n++;
        }
        return n;
    }

    readonly property real fixedWidth: {
        let w = blockLayout.pad + blockLayout.padR;
        let before = 0;
        for (let k = 0; k < rep.count; k++) {
            const o = rep.itemAt(k);
            if (!o)
                continue;
            const pc = Math.min(1, o.pc);
            w += blockLayout.gap * Math.min(pc, before);
            before = Math.max(before, pc);
            w += o.flexible ? (o.fixedPart + o.margin[0] + o.margin[1]) * pc : o.width;
        }
        return w;
    }

    readonly property real dragExtra: {
        const e = block.editor;
        if (!e || e.mode !== "item")
            return 0;
        const g = e.dragW + blockLayout.gap;
        return (e.dropBlock === block.blockId && !e.overDrawer ? g : 0) - (e.fromBlock === block.blockId ? g : 0);
    }

    readonly property string spotlitItem: {
        if (!block.editing || !block.editor)
            return "";
        const sel = block.editor.selectedItem;
        return (sel === "" || sel.indexOf("dash:") === 0 || !BarLayout.entry(sel) || !BarLayout.isPlaced(sel)) ? "" : sel;
    }

    readonly property bool emptyInEdit: block.editing && blockLayout.itemIds.length === 0
    readonly property real naturalWidth: blockLayout.emptyInEdit ? 96 + Math.max(0, blockLayout.dragExtra) : blockLayout.slotLayout.total + blockLayout.pad + blockLayout.padR + blockLayout.dragExtra
    readonly property real collapsedWidth: block.maxWidth > 0 ? Math.min(blockLayout.naturalWidth, Math.max(block.maxWidth, blockLayout.fixedWidth)) : blockLayout.naturalWidth

    readonly property bool isDropTarget: !!block.editor && (block.editor.mode === "item" && block.editor.dropBlock === block.blockId && !block.editor.overDrawer || block.editor.mode === "block" && block.editor.joinTarget === block.blockId)
    readonly property bool isDraggedBlock: !!block.editor && block.editor.mode === "block" && block.editor.fromBlock === block.blockId

    function slotShift(listIndex) {
        const e = block.editor;
        if (!e || e.mode !== "item" || listIndex < 0)
            return 0;
        const g = e.dragW + blockLayout.gap;
        const src = e.fromBlock === block.blockId;
        const tgt = e.dropBlock === block.blockId && !e.overDrawer;
        if (src && listIndex === e.fromIndex)
            return 0;
        let s = 0;
        let j = listIndex;
        if (src && listIndex > e.fromIndex) {
            s -= g;
            j = listIndex - 1;
        }
        if (tgt && j >= e.dropIndex)
            s += g;
        return s;
    }

    function slotUnder(localX) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (!s || !s.visible || s.leaving)
                continue;
            const left = blockLayout.pad + s.x;
            if (localX >= left - blockLayout.gap / 2 && localX <= left + s.width + blockLayout.gap / 2)
                return s;
        }
        return null;
    }

    function itemSpans() {
        const out = [];
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (!s || s.leaving || !s.itemShown || s.width < 1)
                continue;
            out.push({
                l: blockLayout.pad + s.x,
                r: blockLayout.pad + s.x + s.width
            });
        }
        return out.sort((a, b) => a.l - b.l);
    }

    function dropIndexAt(localX) {
        const e = block.editor;
        const src = e.fromBlock === block.blockId;
        const g = e.dragW + blockLayout.gap;
        let n = 0;
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (!s || s.leaving || s.listIndex < 0)
                continue;
            if (src && s.listIndex === e.fromIndex)
                continue;
            const shift = (src && s.listIndex > e.fromIndex) ? -g : 0;
            if (blockLayout.pad + s.x + shift + s.width / 2 < localX)
                n++;
        }
        return n;
    }

    function appGeom() {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (!s || s.leaving || BarLayout.baseId(s.itemId) !== "dockApps" || !s.loaderItem)
                continue;
            const it = s.loaderItem;
            const base = block.absX + blockLayout.pad + s.x + s.contentStart;
            return {
                x: base,
                w: s.contentWidth,
                apps: it.appRects.map(r => ({
                            appId: r.appId,
                            pinned: r.pinned,
                            x: base + r.x,
                            w: r.w
                        }))
            };
        }
        return null;
    }

    function centerOfItem(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && !s.leaving && s.itemId === id)
                return blockLayout.pad + s.x + s.width / 2;
        }
        return block.width / 2;
    }

    function hasItem(id) {
        return blockLayout.itemIds.indexOf(id) >= 0;
    }

    function slotIdOf(item) {
        if (!item)
            return "";
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && s.loaderItem === item)
                return s.itemId;
        }
        return "";
    }

    function ownerIdOf(item) {
        for (let it = item; it && it !== block; it = it.parent) {
            const id = blockLayout.slotIdOf(it);
            if (id !== "")
                return id;
        }
        return "";
    }

    function itemFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && !s.leaving && s.itemId === id)
                return s.loaderItem;
        }
        return null;
    }

    function shownItemFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && !s.leaving && s.itemId === id)
                return s.itemShown ? s.loaderItem : null;
        }
        return null;
    }

    function flightItems() {
        const out = [];
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (s && !s.leaving && s.itemShown && s.loaderItem)
                out.push({
                    id: s.itemId,
                    item: s.loaderItem,
                    slot: s
                });
        }
        return out;
    }

    property real plateX: 0
    property real plateW: 0
    property real plateH: 0
    property real plateR: 0

    function plateFrom(item) {
        blockLayout.plateW = 0;
        if (!item || !block.split)
            return;
        for (let i = 0; i < rep.count; i++) {
            const s = rep.itemAt(i);
            if (!s || s.leaving || s.loaderItem !== item)
                continue;
            const h = BarLayout.plateH(s.itemId, block.barH);
            const shaped = (item.plateShape ?? "") !== "" || BarLayout.plateShape(s.itemId, s.contentWidth, s.contentHeight) !== "";
            const ih = shaped ? h * 0.78 : h - 2;
            const w = shaped ? ih : BarLayout.plateW(s.itemId, s.contentWidth, s.contentHeight, block.barH) - 2;
            const c = s.mapToItem(block, s.margin[0] + s.innerWidth / 2, 0).x;
            blockLayout.plateX = c - w / 2;
            blockLayout.plateH = ih;
            blockLayout.plateR = shaped ? ih / 2 : Math.max(0, BarLayout.plateRadius(s.itemId, h) - 1);
            blockLayout.plateW = w;
            return;
        }
    }

    Rectangle {
        x: 2
        y: 4
        width: Math.max(0, blockLayout.width - 4)
        height: Math.max(0, block.barH - 8)
        radius: block.isPill ? Math.min(height / 2, Math.max(0, block.pillRadius - 4)) : height / 2
        color: Qt.alpha(BarLayout.roleColor(block.tintRole === "none" ? "primary" : block.tintRole), 0.18)
        opacity: block.tintShown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            EffectsAnim {
                speed: "fast"
            }
        }
    }

    Item {
        id: row
        x: blockLayout.pad
        width: blockLayout.slotLayout.total
        height: block.barH

        Repeater {
            id: rep
            model: itemModel

            delegate: Item {
                id: slot

                required property string itemId
                required property int index
                required property bool leaving

                readonly property Item loaderItem: loader.item
                readonly property var entry: BarLayout.entry(slot.itemId)
                readonly property bool loaded: loader.status === Loader.Ready && loader.item !== null
                readonly property bool itemShown: slot.loaded && loader.item.shown
                readonly property bool ghost: block.editing && !slot.itemShown
                readonly property bool anchorPin: !!slot.entry && slot.entry.anchor === true
                readonly property bool flexible: slot.loaded && (loader.item.flexible ?? false)
                readonly property real fixedPart: slot.loaded ? (loader.item.fixedPart ?? 0) : 0
                readonly property int listIndex: slot.leaving ? -1 : block.itemIds.indexOf(slot.itemId)
                readonly property bool dragged: slot.listIndex >= 0 && !!block.editor && block.editor.mode === "item" && block.editor.fromBlock === block.blockId && block.editor.fromIndex === slot.listIndex
                readonly property var margin: BarLayout.marginsFor(slot.itemId)
                readonly property string tintRole: BarLayout.itemStyle(slot.itemId, "tint", "none")
                readonly property bool tinted: slot.tintRole !== "none"
                readonly property real chipRadius: BarLayout.itemStyle(slot.itemId, "radius", -1)
                readonly property real rawW: slot.loaded ? loader.item.implicitWidth : 0
                readonly property real rawH: slot.loaded ? loader.item.implicitHeight : 0
                readonly property bool turns: slot.loaded && loader.item.rotatesWithBar === true
                readonly property bool upright: block.vertical && slot.loaded && !slot.turns && (loader.item.verticalReady === true || slot.rawW <= block.barH - 4)
                readonly property bool sideways: block.vertical && slot.loaded && !slot.turns && !slot.upright
                readonly property bool fullForm: block.vertical && slot.loaded && loader.item.verticalReady !== true
                function noteFull() {
                    if (block && slot.fullForm)
                        block.noteFull(slot.itemId, slot.rawW);
                }
                onRawWChanged: if (slot.fullForm)
                    slot.noteFull()
                onFullFormChanged: if (slot.fullForm)
                    slot.noteFull()
                readonly property real contentWidth: slot.ghost ? 28 : (slot.upright ? slot.rawH : slot.rawW)
                readonly property real contentStart: slot.margin[0] + (slot.innerWidth - slot.contentWidth) / 2
                readonly property real chipWidth: block.split ? BarLayout.plateW(slot.itemId, slot.contentWidth, slot.contentHeight, block.barH) : BarLayout.chipW(slot.itemId, slot.contentWidth, slot.contentHeight, block.barH)
                readonly property real chipHeight: BarLayout.chipH(slot.itemId, slot.contentHeight, block.barH, slot.contentWidth)
                readonly property real contentHeight: slot.upright ? slot.rawW : slot.rawH
                readonly property real innerWidth: Math.max(slot.contentWidth, slot.chipWidth)
                readonly property real revealT: GlobalStates.barRevealAt(block.absX + slot.x + slot.width / 2, block.frameW)
                readonly property bool selected: block.editing && !!block.editor && block.editor.selectedItem === slot.itemId
                readonly property bool isOpener: block.clickedKind !== "" && !!revealer && revealer.openerId === slot.itemId

                readonly property bool wanted: !slot.leaving && (slot.itemShown || block.editing)
                property real presence: 0
                readonly property real pc: Math.max(0, slot.presence)
                Behavior on presence {
                    enabled: BarLayout.settled
                    SpatialAnim {
                        speed: "fast"
                    }
                }

                onPresenceChanged: if (slot.leaving && slot.presence <= 0.001)
                    blockLayout.slotGone(slot.itemId)
                Component.onCompleted: slot.presence = Qt.binding(() => slot.wanted ? 1 : 0)

                x: blockLayout.slotLayout.xs[slot.index] ?? 0
                visible: slot.pc > 0.001
                width: (slot.innerWidth + slot.margin[0] + slot.margin[1]) * slot.pc
                height: block.barH
                clip: slot.pc < 0.999
                readonly property bool dimmed: (blockLayout.spotlitItem !== "" && !slot.selected) || block.otherBlockSelected
                readonly property bool covered: block.coveredAt(slot.x, slot.width)
                opacity: (slot.dragged || slot.covered ? 0 : Math.min(1, slot.pc)) * (slot.dimmed ? 0.45 : 1)

                Behavior on opacity {
                    enabled: BarLayout.settled
                    EffectsAnim {
                        speed: "fast"
                    }
                }

                transform: Translate {
                    x: blockLayout.slotShift(slot.listIndex)
                    Behavior on x {
                        SpatialAnim {
                            speed: "fast"
                        }
                    }
                }

                BarItemPlate {
                    x: slot.margin[0]
                    anchors.verticalCenter: parent.verticalCenter
                    width: slot.innerWidth
                    height: block.barH
                    itemId: slot.itemId
                    contentWidth: slot.contentWidth
                    contentHeight: slot.contentHeight
                    barH: block.barH
                    turned: block.vertical
                    far: block.far
                    fill: slot.loaded && (loader.item.plateShape ?? "") !== "" ? loader.item.plateTone : block.plateFill
                    shapeOverride: slot.loaded ? (loader.item.plateShape ?? "") : ""
                    shapeInset: slot.loaded ? (loader.item.plateInset ?? 0) : 0
                    hovered: slotHover.hovered && !BarLayout.isGroup(slot.itemId) && (!slot.loaded || loader.item.hoverPlate !== false)
                    shown: slot.itemShown && block.split
                }

                BarItemChip {
                    x: slot.margin[0]
                    anchors.verticalCenter: parent.verticalCenter
                    width: slot.innerWidth
                    height: block.barH
                    itemId: slot.itemId
                    contentWidth: slot.contentWidth
                    contentHeight: slot.contentHeight
                    barH: block.barH
                    turned: block.vertical
                    shown: slot.itemShown && !block.split
                    plateColor: slot.loaded && loader.item.plateOn === true ? loader.item.plateColor : "transparent"
                    hovered: slotHover.hovered && slot.tinted && !BarLayout.isGroup(slot.itemId)
                }

                HoverHandler {
                    id: slotHover
                    enabled: slot.tinted || block.split
                }

                readonly property string hoverPanel: BarLayout.openOn(slot.itemId) === "hover" ? BarLayout.followKind(slot.itemId) : ""
                HoverHandler {
                    id: openHover
                    enabled: slot.hoverPanel !== "" && !block.editing && slot.loaded && slot.itemShown
                    onHoveredChanged: {
                        if (openHover.hovered)
                            openDelay.restart();
                        else
                            openDelay.stop();
                    }
                }
                Timer {
                    id: openDelay
                    interval: 140
                    onTriggered: if (openHover.hovered && slot.hoverPanel !== "")
                        block.hoverOpen(slot.hoverPanel, slot.loaderItem)
                }

                readonly property string clickPanel: !slot.loaded || BarLayout.openOn(slot.itemId) !== "click" ? "" : BarLayout.baseId(slot.itemId) === "clock" ? "calendar" : BarLayout.baseId(slot.itemId) === "music" ? (loader.item.panelKind ?? "") : ""
                MouseArea {
                    anchors.fill: parent
                    enabled: slot.clickPanel !== "" && !block.editing && slot.itemShown
                    visible: enabled
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: block.openPanel(slot.clickPanel, slot.loaderItem)
                }

                HoverHandler {
                    enabled: slot.loaded && slot.itemShown && !block.editing && BarLayout.hasOpenChoice(slot.itemId)
                    cursorShape: Qt.PointingHandCursor
                }

                Loader {
                    id: loader
                    x: slot.contentStart + (slot.contentWidth - slot.rawW) / 2
                    y: (block.barH - slot.rawH) / 2
                    transform: slot.upright ? [uprightM] : slot.sideways ? [sidewaysM] : []
                    source: Qt.resolvedUrl(BarLayout.fileFor(slot.itemId))

                    Matrix4x4 {
                        id: uprightM
                        matrix: block.flipAbout(slot.rawW, slot.rawH)
                    }
                    Matrix4x4 {
                        id: sidewaysM
                        matrix: block.mirrorAbout(slot.rawW, slot.rawH)
                    }
                    visible: slot.itemShown
                    opacity: slot.isOpener || (layout.flyHidden[slot.itemId] ?? false) ? 0 : 1
                    Behavior on opacity {
                        EffectsAnim {
                            speed: "fast"
                        }
                    }
                    onLoaded: {
                        item.host = block;
                        if ("itemId" in item)
                            item.itemId = slot.itemId;
                    }
                }

                Rectangle {
                    visible: slot.ghost && slot.anchorPin && slot.revealT > 0.001
                    opacity: slot.revealT
                    x: slot.margin[0] + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: slot.selected ? Colors.primary : Colors.primaryContainer
                }

                MaterialIconSymbol {
                    id: ghostIcon
                    visible: slot.ghost && slot.revealT > 0.001
                    opacity: (slot.anchorPin ? 1 : 0.6) * slot.revealT
                    x: slot.margin[0] + (28 - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    transform: block.vertical ? [ghostFlip] : []

                    Matrix4x4 {
                        id: ghostFlip
                        matrix: block.flipAbout(ghostIcon.width, ghostIcon.height)
                    }
                    content: slot.entry ? slot.entry.icon : ""
                    iconSize: slot.anchorPin ? 16 : 18
                    fill: slot.anchorPin ? 1 : 0
                    customColor: !slot.anchorPin ? Colors.outline : slot.selected ? Colors.primaryText : Colors.primaryContainerText
                }

                Rectangle {
                    id: closeBadge
                    x: slot.margin[0] + (slot.innerWidth - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: slot.isOpener ? 28 : 12
                    height: width
                    radius: width / 2
                    color: closeArea.containsMouse ? Colors.primary : Colors.primaryContainer
                    opacity: slot.isOpener ? 1 : 0
                    visible: closeBadge.opacity > 0.01
                    Behavior on opacity {
                        EffectsAnim {
                            speed: "fast"
                        }
                    }
                    Behavior on width {
                        SpatialAnim {
                            speed: "fast"
                        }
                    }
                    Behavior on color {
                        EffectsColorAnim {
                            speed: "fast"
                        }
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"
                        iconSize: slot.isOpener ? 16 : 7
                        Behavior on iconSize {
                            SpatialAnim {
                                speed: "fast"
                            }
                        }
                        customColor: closeArea.containsMouse ? Colors.primaryText : Colors.primaryContainerText
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        enabled: slot.isOpener
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: block.closePanel()
                    }

                    CustomToolTip {
                        content: "Close"
                        visible: closeArea.containsMouse
                    }
                }

                Rectangle {
                    id: selRing
                    visible: slot.selected
                    x: slot.margin[0] - 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: slot.innerWidth + 6
                    height: Math.max(32, slot.chipHeight + 6)
                    radius: 10
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.primary
                    property real settle: 1
                    scale: 1 + 0.22 * (1 - selRing.settle)
                    onVisibleChanged: if (selRing.visible)
                        ringSettle.restart()

                    NumberAnimation {
                        id: ringSettle
                        target: selRing
                        property: "settle"
                        from: 0
                        to: 1
                        duration: 340
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: selRing.radius + 4
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.alpha(Colors.primary, 0.22)
                    }
                }
            }
        }
    }

    CustomText {
        id: dropHint
        anchors.centerIn: parent
        visible: blockLayout.emptyInEdit
        transform: block.vertical ? [dropFlip] : []

        Matrix4x4 {
            id: dropFlip
            matrix: block.mirrorAbout(dropHint.width, dropHint.height)
        }
        content: "Drop here"
        size: 11
        weight: 600
        customColor: Colors.outline
    }
}
