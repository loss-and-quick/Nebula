import Quickshell
import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom
import "BarOps.js" as BarOps

Item {
    id: barBlock

    required property string blockId
    required property int index
    required property bool leaving
    property QtObject editor: null
    property real maxWidth: -1
    property real absX: 0
    property var coverTabs: []
    property real spanL: 0
    property real spanR: 0
    property real spanF: 0
    property string edge: "top"
    property Item frame: null
    property var fullW: ({})
    property var lastInfo: null
    property real clearT: barBlock.split ? 1 : 0
    property real pillTintT: barBlock.isPill && barBlock.tintRole !== "none" && !barBlock.split ? 1 : 0
    property color pillTintColor: BarLayout.roleColor(barBlock.tintRole === "none" ? "primary" : barBlock.tintRole)
    property real fadeK: barBlock.isPill && !barBlock.split ? 1 - barBlock.pillOpacity : 0
    property real pillT: barBlock.isPill ? 1 : 0
    property real flatT: barBlock.shape === "flat" ? 1 : 0
    property real drop: barBlock.gaps ? Math.max(0, barBlock.gaps.edge) : (barBlock.frame ? barBlock.frame.pillMargin : 0) * barBlock.pillT
    property real pillRadius: {
        const r = barBlock.gaps ? barBlock.gaps.radius : BarLayout.blockStyle(barBlock.blockId, "radius", -1);
        return r < 0 ? barBlock.barH / 2 : Math.min(r, barBlock.barH / 2);
    }
    property real lineUp: barBlock.frame && barBlock.frame.lineUpDepth ? barBlock.frame.lineUpDepth * barBlock.stepT : 0
    property real presence: 0
    property real tuckAwayT: barBlock.tuckedAway ? 1 : 0

    signal gone

    Behavior on clearT {
        EffectsAnim {
            speed: "default"
        }
    }
    Behavior on pillTintT {
        EffectsAnim {
            speed: "default"
        }
    }
    Behavior on pillTintColor {
        EffectsColorAnim {}
    }
    Behavior on fadeK {
        EffectsAnim {
            speed: "default"
        }
    }
    Behavior on pillT {
        enabled: BarLayout.settled
        SpatialAnim {
            speed: "default"
        }
    }
    Behavior on flatT {
        enabled: BarLayout.settled
        SpatialAnim {
            speed: "default"
        }
    }
    Behavior on drop {
        enabled: BarLayout.settled && barBlock.gaps !== null && !BarLayout.gapDragging
        SpatialAnim {
            speed: "default"
        }
    }
    Behavior on pillRadius {
        enabled: BarLayout.settled && barBlock.gaps !== null && !BarLayout.gapDragging
        SpatialAnim {
            speed: "default"
        }
    }
    Behavior on lineUp {
        enabled: BarLayout.settled
        SpatialAnim {
            speed: "default"
        }
    }
    Behavior on presence {
        enabled: BarLayout.settled
        SpatialAnim {
            speed: "default"
        }
    }
    Behavior on tuckAwayT {
        EffectsAnim {
            speed: "fast"
        }
    }
    Behavior on implicitWidth {
        enabled: BarLayout.settled
        NumberAnimation {
            duration: M3Motion.spatialDuration("fast")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1, 1]
        }
    }

    readonly property var edgeCfg: BarLayout.edge(barBlock.edge)
    readonly property bool far: barBlock.frame ? barBlock.frame.far : BarOps.isFarSide(barBlock.edge)
    readonly property bool vertical: barBlock.frame ? barBlock.frame.vertical : false
    readonly property bool sideCrowded: barBlock.vertical && !!barBlock.frame && !!barBlock.frame.compactIds && barBlock.frame.compactIds[barBlock.blockId] === true
    readonly property real frameW: barBlock.frame ? barBlock.frame.width : layout.width
    readonly property real frameH: barBlock.frame ? barBlock.frame.height : layout.height
    readonly property real iconSize: barBlock.edgeCfg.iconSize
    readonly property real appIconSize: barBlock.iconSize > 0 ? barBlock.iconSize : Math.max(16, barBlock.barH - 16)
    readonly property var liveInfo: BarLayout.blockById(barBlock.blockId)
    readonly property var info: barBlock.liveInfo ?? barBlock.lastInfo
    readonly property var itemIds: barBlock.info ? barBlock.info.items : []
    readonly property string anchorSide: barBlock.info ? barBlock.info.anchor : "left"
    readonly property bool editMode: GlobalStates.barEditMode && layout.isPrimary
    readonly property bool editing: barBlock.editMode && !barBlock.leaving
    readonly property bool blockSelected: !!barBlock.editor && barBlock.editor.selectedBlock === barBlock.blockId
    readonly property bool otherBlockSelected: barBlock.editing && !!barBlock.editor && barBlock.editor.selectedBlock !== "" && !barBlock.blockSelected
    readonly property real revealT: GlobalStates.barRevealAt(barBlock.absX + barBlock.width / 2, barBlock.frameW)
    readonly property bool handlesIn: barBlock.revealT > 0.55
    readonly property string shape: BarLayout.blockShape(barBlock.blockId, barBlock.edge)
    readonly property bool isPill: barBlock.shape === "pill"
    readonly property bool sticky: BarLayout.blockStyle(barBlock.blockId, "sticky", false) === true
    readonly property string tintRole: BarLayout.blockStyle(barBlock.blockId, "tint", "none")
    readonly property bool tintShown: barBlock.tintRole !== "none" && !barBlock.isPill && barBlock.itemIds.length > 0
    readonly property bool split: barBlock.isPill && BarLayout.splitBlock(barBlock.blockId)
    readonly property color plateFill: barBlock.tintRole === "none" ? Colors.surface : Qt.tint(Colors.surface, Qt.alpha(BarLayout.roleColor(barBlock.tintRole), 0.22))
    readonly property real pillOpacity: Math.max(0, Math.min(100, BarLayout.blockStyle(barBlock.blockId, "opacity", 100))) / 100
    readonly property real pillClear: Math.max(barBlock.clearT, barBlock.fadeK)
    readonly property real pillTintRgb: Math.round(barBlock.pillTintColor.r * 255) * 65536 + Math.round(barBlock.pillTintColor.g * 255) * 256 + Math.round(barBlock.pillTintColor.b * 255)
    readonly property var gaps: BarLayout.gapModel ? BarLayout.blockGaps(barBlock.blockId, barBlock.edge) : null
    readonly property real gapBefore: barBlock.gaps ? barBlock.gaps.gapBefore : -1
    readonly property real offset: barBlock.gaps ? barBlock.gaps.offset : 0
    readonly property var screenCorners: {
        const c = BarLayout.blockCorners(barBlock.blockId);
        const f = k => c[k] === null ? barBlock.pillRadius : Math.min(c[k], barBlock.barH / 2);
        return {
            tl: f("tl"),
            tr: f("tr"),
            br: f("br"),
            bl: f("bl"),
            custom: c.tl !== null || c.tr !== null || c.br !== null || c.bl !== null
        };
    }
    readonly property var frameCorners: {
        const c = barBlock.screenCorners;
        if (!c.custom)
            return null;
        switch (barBlock.edge) {
        case "bottom":
            return {
                nl: c.bl,
                nr: c.br,
                fl: c.tl,
                fr: c.tr
            };
        case "left":
            return {
                nl: c.tl,
                nr: c.bl,
                fl: c.tr,
                fr: c.br
            };
        case "right":
            return {
                nl: c.tr,
                nr: c.br,
                fl: c.tl,
                fr: c.bl
            };
        }
        return {
            nl: c.tl,
            nr: c.tr,
            fl: c.bl,
            fr: c.br
        };
    }
    readonly property bool bumpHiding: !!barBlock.frame && barBlock.frame.bumpMode === true
    readonly property real hideT: !barBlock.bumpHiding ? 1 : Math.max(0, Math.min(1, barBlock.isPill ? barBlock.frame.reveal : barBlock.frame.bumpDepth))
    readonly property real hideLift: !barBlock.bumpHiding ? 0 : barBlock.isPill ? barBlock.frame.slide : (1 - barBlock.frame.bumpDepth) * (barBlock.barH + barBlock.frame.edgeInset)
    readonly property real barH: barBlock.edgeCfg.height
    readonly property real stepT: (1 - barBlock.pillT) * (1 - barBlock.flatT)
    readonly property real roundT: barBlock.pillT + barBlock.stepT
    property bool dockHovered: false
    readonly property bool hovering: blockHover.hovered || revealer.tabHovered || barBlock.dockHovered
    readonly property bool wantedBase: !barBlock.leaving && SettingsConfig.settingsReady && (barBlock.editMode || barBlock.panelKind !== "" || barBlock.shownCount > 0)
    readonly property bool folded: !!barBlock.frame && !!barBlock.frame.foldIds && barBlock.frame.foldIds.indexOf(barBlock.blockId) >= 0
    readonly property bool wanted: barBlock.wantedBase && !barBlock.folded
    readonly property real pc: Math.max(0, barBlock.presence)
    readonly property bool tuckedAway: barBlock.frame && barBlock.frame.pushPlan ? !!barBlock.frame.pushPlan.hide[barBlock.blockId] : false

    readonly property var geomSig: [barBlock.x, barBlock.y, barBlock.width, barBlock.visible, barBlock.pc, barBlock.pillRadius, barBlock.frameCorners, barBlock.pillT, barBlock.flatT, barBlock.drop, barBlock.tabOpen, barBlock.fixedWidth, barBlock.wantedBase, barBlock.leaving, barBlock.shape, barBlock.floating, barBlock.merged, barBlock.anchorSide, barBlock.clearT, barBlock.fadeK, barBlock.pillTintT, barBlock.pillTintRgb, barBlock.lineUp, barBlock.panelCorner]
    onGeomSigChanged: if (barBlock.frame && barBlock.frame.markGeom)
        barBlock.frame.markGeom()
    readonly property var tabSig: [revealer.tabX, revealer.tabW, revealer.tabH, revealer.goo, revealer.gooX, revealer.gooW, revealer.gooH, revealer.srcX, revealer.srcW, revealer.gooHost]
    onTabSigChanged: {
        if (!barBlock.frame)
            return;
        if (revealer.gliding && barBlock.frame.recomputeTabs)
            barBlock.frame.recomputeTabs();
        else if (barBlock.frame.markTabs)
            barBlock.frame.markTabs();
    }

    onLiveInfoChanged: if (barBlock.liveInfo)
        barBlock.lastInfo = barBlock.liveInfo
    onPresenceChanged: if (barBlock.leaving && barBlock.presence <= 0.001)
        barBlock.gone()
    Component.onCompleted: {
        barBlock.lastInfo = barBlock.liveInfo;
        barBlock.presence = Qt.binding(() => barBlock.wanted ? 1 : 0);
    }

    function coveredAt(x0, w) {
        if (GlobalStates.barEditMode || !barBlock.isPill)
            return false;
        const l = barBlock.absX + x0;
        const r = l + w;
        for (const t of barBlock.coverTabs) {
            if (t.id === barBlock.blockId)
                continue;
            if (t.r > l + 1 && t.l < r - 1)
                return true;
        }
        return false;
    }

    function noteFull(id, w) {
        if (w <= 0 || Math.abs((barBlock.fullW[id] ?? -1) - w) < 0.5)
            return;
        const n = Object.assign({}, barBlock.fullW);
        n[id] = w;
        barBlock.fullW = n;
    }

    function compactFor(id) {
        return barBlock.sideCrowded && (barBlock.fullW[id] ?? Infinity) > barBlock.barH - 4;
    }

    function flipAbout(w, h) {
        return Qt.matrix4x4(0, 1, 0, (w - h) / 2, 1, 0, 0, (h - w) / 2, 0, 0, 1, 0, 0, 0, 0, 1);
    }

    function mirrorAbout(w, h) {
        return barBlock.frame && barBlock.frame.side === "right" ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, h, 0, 0, 1, 0, 0, 0, 0, 1) : Qt.matrix4x4(-1, 0, 0, w, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    }

    function checkHoverLeave() {
        if (barBlock.clickedKind !== "" || (revealer.launchHost && GlobalStates.appLauncherOpen))
            return;
        if (!blockHover.hovered && (!revealer || !revealer.tabHovered))
            revealer.hoverKind = "";
    }

    // Forwarding to BlockLayout
    readonly property alias itemModel: blockLayout.itemModel
    readonly property alias slotLayout: blockLayout.slotLayout
    readonly property alias shownCount: blockLayout.shownCount
    readonly property alias fixedWidth: blockLayout.fixedWidth
    readonly property alias naturalWidth: blockLayout.naturalWidth
    readonly property alias collapsedWidth: blockLayout.collapsedWidth
    readonly property alias pad: blockLayout.pad
    readonly property alias padR: blockLayout.padR
    readonly property alias plateX: blockLayout.plateX
    readonly property alias plateW: blockLayout.plateW
    readonly property alias plateH: blockLayout.plateH
    readonly property alias plateR: blockLayout.plateR
    readonly property alias emptyInEdit: blockLayout.emptyInEdit
    readonly property alias isDropTarget: blockLayout.isDropTarget
    readonly property alias isDraggedBlock: blockLayout.isDraggedBlock
    readonly property alias spotlitItem: blockLayout.spotlitItem
    readonly property alias caeStyle: revealer.caeStyle

    function hasItem(id) {
        return blockLayout.hasItem(id);
    }
    function itemFor(id) {
        return blockLayout.itemFor(id);
    }
    function shownItemFor(id) {
        return blockLayout.shownItemFor(id);
    }
    function slotIdOf(item) {
        return blockLayout.slotIdOf(item);
    }
    function ownerIdOf(item) {
        return blockLayout.ownerIdOf(item);
    }
    function centerOfItem(id) {
        return blockLayout.centerOfItem(id);
    }
    function slotUnder(localX) {
        return blockLayout.slotUnder(localX);
    }
    function itemSpans() {
        return blockLayout.itemSpans();
    }
    function dropIndexAt(localX) {
        return blockLayout.dropIndexAt(localX);
    }
    function slotShift(listIndex) {
        return blockLayout.slotShift(listIndex);
    }
    function appGeom() {
        return blockLayout.appGeom();
    }
    function plateFrom(item) {
        blockLayout.plateFrom(item);
    }
    function flightItems() {
        return blockLayout.flightItems();
    }

    // Forwarding to ContentHost
    readonly property alias slotA: contentHost.slotA
    readonly property alias slotB: contentHost.slotB
    readonly property alias curSlot: contentHost.curSlot
    readonly property alias curSlotItem: contentHost.curSlotItem

    function itemOf(k) {
        return contentHost.itemOf(k);
    }
    function preload(k) {
        contentHost.preload(k);
    }
    function prepare(k) {
        return contentHost.prepare(k);
    }
    function prepareContent(k) {
        return contentHost.prepareContent(k);
    }
    function show(k) {
        contentHost.show(k);
    }
    function showContent(k) {
        contentHost.showContent(k);
    }

    // Forwarding to PanelRevealer
    readonly property alias state: revealer.state
    readonly property alias tabX: revealer.tabX
    readonly property alias tabW: revealer.tabW
    readonly property alias tabH: revealer.tabH
    readonly property alias tabHRaw: revealer.tabHRaw
    readonly property alias tabTargetX: revealer.tabTargetX
    readonly property alias tabTargetW: revealer.tabTargetW
    readonly property alias tabTargetH: revealer.tabTargetH
    readonly property alias tabPathH: revealer.tabPathH
    readonly property alias tabBaseX: revealer.tabBaseX
    readonly property alias tabNaturalW: revealer.tabNaturalW
    readonly property alias tabNaturalX: revealer.tabNaturalX
    readonly property alias tabOpen: revealer.tabOpen
    readonly property alias tabMoving: revealer.tabMoving
    readonly property alias panelKind: revealer.panelKind
    readonly property alias shownKind: revealer.shownKind
    readonly property alias closing: revealer.closing
    readonly property alias closedAt: revealer.closedAt
    readonly property alias gliding: revealer.gliding
    readonly property alias goo: revealer.goo
    readonly property alias gooSnap: revealer.gooSnap
    readonly property alias gooX: revealer.gooX
    readonly property alias gooW: revealer.gooW
    readonly property alias gooH: revealer.gooH
    readonly property alias gooHost: revealer.gooHost
    readonly property alias gooShape: revealer.gooShape
    readonly property alias srcX: revealer.srcX
    readonly property alias srcW: revealer.srcW
    readonly property alias clickedKind: revealer.clickedKind
    readonly property alias hoverKind: revealer.hoverKind
    readonly property alias lastKind: revealer.lastKind
    readonly property alias openerId: revealer.openerId
    readonly property alias openLocked: revealer.openLocked
    readonly property alias openAlong: revealer.openAlong
    readonly property alias openAcross: revealer.openAcross
    readonly property alias tuckHost: revealer.tuckHost
    readonly property alias tuckers: revealer.tuckers
    readonly property alias tuckPopup: revealer.tuckPopup
    readonly property alias tuckOsd: revealer.tuckOsd
    readonly property alias tuckH: revealer.tuckH
    readonly property alias tuckShown: revealer.tuckShown
    readonly property alias trayCount: revealer.trayCount
    readonly property alias trayOffset: revealer.trayOffset
    readonly property alias trayHidden: revealer.trayHidden
    readonly property alias trayCols: revealer.trayCols
    readonly property alias trayRows: revealer.trayRows
    readonly property alias trayMenuItem: revealer.trayMenuItem
    readonly property alias trayMenuAlive: revealer.trayMenuAlive
    readonly property alias dockAppId: revealer.dockAppId
    readonly property alias dockAppEntry: revealer.dockAppEntry
    readonly property alias dockWinCount: revealer.dockWinCount
    readonly property alias dockPreviewCap: revealer.dockPreviewCap
    readonly property alias dockPreviewWidth: revealer.dockPreviewWidth
    readonly property alias panelStyle: revealer.panelStyle
    readonly property alias floating: revealer.floating
    readonly property alias fusedAttach: revealer.fusedAttach
    readonly property alias merged: revealer.merged
    readonly property alias crowded: revealer.crowded
    readonly property alias panelGapSetting: revealer.panelGapSetting
    readonly property alias fusedHost: revealer.fusedHost
    readonly property alias floatGap: revealer.floatGap
    readonly property alias openHeight: revealer.openHeight
    readonly property alias panelRoom: revealer.panelRoom
    readonly property alias heightRoom: revealer.heightRoom
    readonly property alias widthRoom: revealer.widthRoom
    readonly property alias drawer: revealer.drawer
    readonly property alias panelCorner: revealer.panelCorner
    readonly property alias contentNearL: revealer.contentNearL
    readonly property alias contentNearR: revealer.contentNearR
    readonly property alias sysHost: revealer.sysHost
    readonly property alias launchHost: revealer.launchHost
    readonly property alias previewHost: revealer.previewHost
    readonly property alias osdHost: revealer.osdHost
    readonly property alias osdWant: revealer.osdWant
    readonly property alias popupHost: revealer.popupHost
    readonly property alias popupWant: revealer.popupWant

    function openPanel(kind, item) {
        revealer.openPanel(kind, item);
    }
    function closePanel() {
        revealer.closePanel();
    }
    function hoverOpen(kind, item) {
        revealer.hoverOpen(kind, item);
    }
    function beginOpen(kind, item, clicked) {
        revealer.beginOpen(kind, item, clicked);
    }
    function isTransient(k) {
        return revealer.isTransient(k);
    }
    function acrossOf(k) {
        return revealer.acrossOf(k);
    }
    function alongOf(k) {
        return revealer.alongOf(k);
    }
    function kindWidth(k) {
        return revealer.kindWidth(k);
    }
    function contentHeight(k) {
        return revealer.contentHeight(k);
    }
    function openTrayOverflow(source, limit, clicked) {
        revealer.openTrayOverflow(source, limit, clicked);
    }
    function openTrayMenu(trayItem, source) {
        revealer.openTrayMenu(trayItem, source);
    }
    function appEntered(entry, item) {
        revealer.appEntered(entry, item);
    }
    function appExited() {
        revealer.appExited();
    }
    function appMenu(entry, item) {
        revealer.appMenu(entry, item);
    }
    function contentCorner(corner, farR) {
        return revealer.contentCorner(corner, farR);
    }
    function contentFar(attachedR) {
        return revealer.contentFar(attachedR);
    }
    function updateCrowded() {
        revealer.updateCrowded();
    }
    function previewOpener(k) {
        return revealer.previewOpener(k);
    }

    // Forwarding to BlockEditor
    readonly property alias resizing: blockEditor.resizing
    readonly property alias resizeKind: blockEditor.resizeKind
    readonly property alias sizeKind: blockEditor.sizeKind
    readonly property alias sizeHandles: blockEditor.sizeHandles
    readonly property alias gripShown: blockEditor.gripShown
    readonly property alias gripHovered: blockEditor.gripHovered

    function beginResize() {
        blockEditor.beginResize();
    }
    function updateResize(w, h) {
        blockEditor.updateResize(w, h);
    }
    function endResize() {
        blockEditor.endResize();
    }

    // Panels provider
    readonly property alias panels: panels

    y: barBlock.far ? -barBlock.drop + barBlock.hideLift : barBlock.drop - barBlock.hideLift
    visible: barBlock.pc > 0.001
    z: blockEditor.gripHovered ? 1 : 0
    width: barBlock.implicitWidth * barBlock.pc
    height: barBlock.barH
    implicitWidth: barBlock.sticky && barBlock.frame && barBlock.frame.stickyRoom ? barBlock.frame.stickyRoom(barBlock) : blockLayout.collapsedWidth
    implicitHeight: barBlock.barH
    enabled: !barBlock.tuckedAway
    opacity: (blockLayout.isDraggedBlock ? 0.35 : 1) * Math.min(1, barBlock.pc) * barBlock.hideT * (1 - barBlock.tuckAwayT)

    HoverHandler {
        id: blockHover
        onHoveredChanged: if (!hovered)
            barBlock.checkHoverLeave()
    }

    BarBlockPanels {
        id: panels
        block: barBlock
    }

    BlockLayout {
        id: blockLayout
        z: 2
        block: barBlock
        revealer: revealer
    }

    PanelRevealer {
        id: revealer
        z: 1
        block: barBlock
        contentHost: contentHost

        ContentHost {
            id: contentHost
            block: barBlock
            revealer: revealer
        }
    }

    BlockEditor {
        id: blockEditor
        block: barBlock
        revealer: revealer
    }
}
