import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom
import qs.modules.components.Clipboard
import qs.modules.components.WallpaperSelector
import qs.modules.components.Osd
import qs.modules.components.AppLauncher
import qs.modules.components.CustomContextMenu
import "BarOps.js" as BarOps

Item {
    id: revealer

    required property Item block
    property Item contentHost: null
    default property alias contentData: clipItem.data
    readonly property alias clipItem: clipItem
    readonly property alias tabHover: tabHover
    readonly property bool tabHovered: tabHover.hovered

    property real tabX: 0
    property real tabW: 0
    property real tabHRaw: 0
    readonly property real tabH: Math.max(block.barH, revealer.tabHRaw)
    readonly property real tabTargetX: {
        const l = revealer.tabNaturalX;
        const r = l + revealer.tabNaturalW;
        if (revealer.snapInR(r))
            return block.width - revealer.tabNaturalW;
        if (revealer.snapInL(l))
            return 0;
        return l;
    }
    readonly property real tabTargetW: revealer.tabNaturalW
    readonly property real tabTargetH: block.barH + (revealer.heightFollow ? revealer.followAcross : (revealer.openLocked ? revealer.openAcross : revealer.acrossOf(revealer.shownKind)) + revealer.tuckShown)
    readonly property real tabPathH: revealer.tabH + (revealer.merged ? revealer.floatGap : 0)
    readonly property bool tabMoving: tabXAnim.running || tabWAnim.running || tabHAnim.running || openTrans.running || closeTrans.running
    readonly property bool tabOpen: revealer.shownKind !== "" || revealer.tabH > block.barH + 0.5 || (revealer.floating && revealer.goo > 0.001)

    // Panel styling and geometry
    readonly property string panelStyle: BarLayout.panelStyleFor(block.blockId, block.edge, block.shape)
    readonly property bool floating: revealer.panelStyle === "floating"
    readonly property bool fusedAttach: revealer.panelStyle === "attached" && block.isPill && !!block.frame && !!block.frame.fused && (block.frame.fused[block.blockId]?.ids.length ?? 1) > 1
    readonly property bool merged: revealer.panelStyle === "merged" || revealer.crowded || revealer.fusedAttach
    property bool crowded: false

    function updateCrowded() {
        if (revealer.shownKind !== "") {
            if (!revealer.crowded)
                revealer.crowded = revealer.panelStyle === "attached" && !!block.frame && !!block.frame.crowds && block.frame.crowds(block);
        } else if (!revealer.tabOpen) {
            revealer.crowded = false;
        }
    }
    onTabOpenChanged: revealer.updateCrowded()
    onTabNaturalWChanged: revealer.updateCrowded()

    readonly property real panelGapSetting: BarLayout.blockPanelGap(block.blockId)
    readonly property bool fusedHost: revealer.merged && !!block.frame && !!block.frame.fusedCovers && block.frame.fusedCovers(block, revealer.tabTargetX, revealer.tabNaturalW)
    readonly property real floatGap: revealer.floating ? revealer.panelGapSetting : revealer.fusedHost ? 0 : revealer.merged ? Math.max(revealer.panelGapSetting, revealer.crowded || revealer.fusedAttach ? 8 : 0) * Math.max(0, Math.min(1, (revealer.tabH - block.barH) / 24)) : 0

    readonly property real openHeight: block.frameH - (block.isPill ? (block.frame ? block.frame.pillMargin : ServiceGaps.pillMargin) * 2 : 0)
    readonly property real panelRoom: revealer.openHeight - block.barH - (revealer.floating || revealer.merged ? revealer.panelGapSetting : 0) - (block.frame ? Math.max(block.frame.panelFar, block.frame.farReserve) + block.frame.borderNear : 0)
    readonly property real heightRoom: block.vertical ? block.spanR - block.spanL : revealer.panelRoom
    readonly property real widthRoom: block.vertical ? revealer.panelRoom : block.frameW - 32
    readonly property bool drawer: block.flatT > 0.5 && !block.isPill && !revealer.floating && !revealer.merged
    readonly property real panelCorner: {
        const own = BarLayout.panelRadius(revealer.shownKind !== "" ? revealer.shownKind : revealer.lastKind);
        return own >= 0 ? own : block.frame ? block.frame.disX : 0;
    }
    readonly property real contentNearL: revealer.floating ? revealer.panelCorner : revealer.merged && revealer.tabX < -0.5 ? revealer.panelCorner : 0
    readonly property real contentNearR: revealer.floating ? revealer.panelCorner : revealer.merged && revealer.tabX + revealer.tabW > block.width + 0.5 ? revealer.panelCorner : 0

    function contentCorner(corner, farR) {
        const top = corner[0] === "t";
        const left = corner[1] === "l";
        if (!block.vertical)
            return (block.far ? !top : top) ? (left ? revealer.contentNearL : revealer.contentNearR) : revealer.contentFar(farR);
        return (block.far ? !left : left) ? (top ? revealer.contentNearL : revealer.contentNearR) : revealer.contentFar(farR);
    }

    function contentFar(attachedR) {
        if (revealer.merged || revealer.floating)
            return revealer.panelCorner;
        if (block.isPill)
            return attachedR;
        return revealer.acrossOf(revealer.lastKind) >= revealer.panelRoom - 1 ? 0 : revealer.panelCorner;
    }

    // Host triggers
    readonly property bool sysHost: block.edge === BarLayout.sysEdge && layout.isPrimary && block.blockId === BarLayout.sysHostId
    readonly property bool launchHost: layout.isPrimary && !block.leaving && (ServiceLauncher.position === "item" || ServiceLauncher.position === "block") && block.hasItem("launcher")
    function previewOpener(k) {
        return BarLayout.panelHostItem(k);
    }
    readonly property bool previewHost: layout.isPrimary && !block.leaving && GlobalStates.panelPreview !== "" && (GlobalStates.panelPreview === "wallpaper" || GlobalStates.panelPreview === "clipboard" ? revealer.hostsSys(GlobalStates.panelPreview) : block.hasItem(revealer.previewOpener(GlobalStates.panelPreview)))
    readonly property bool osdHost: layout.isPrimary && BarLayout.osdHostItem !== "" && block.hasItem(BarLayout.osdHostItem)
    readonly property bool osdWant: revealer.osdHost && GlobalStates.osdOpen
    readonly property bool popupHost: layout.isPrimary && BarLayout.popupMode === "item" && block.hasItem(BarLayout.popupHostItem)
    readonly property bool popupWant: revealer.popupHost && ServiceNotification.popups.length > 0 && !GlobalStates.notificationCenterOpen

    property bool openLocked: false
    property real openAlong: 0
    property real openAcross: 0

    property real goo: revealer.floating && revealer.shownKind !== "" ? 1 : 0
    Behavior on goo {
        enabled: revealer.floating && !revealer.gooSnap
        NumberAnimation {
            duration: revealer.quickMotion ? (revealer.shownKind !== "" ? 380 : 260) : revealer.shownKind !== "" ? 520 : 400
            easing.type: revealer.quickMotion && revealer.shownKind === "" ? Easing.OutCubic : Easing.InOutCubic
        }
    }
    property bool gooSnap: false
    property real gooX: 0
    property real gooW: 0
    property real gooH: 0

    function trackGoo() {
        if (revealer.shownKind === "")
            return;
        revealer.gooX = revealer.tabX;
        revealer.gooW = revealer.tabW;
        revealer.gooH = Math.max(0, revealer.tabH - block.barH);
    }

    readonly property var gooHost: block.split && block.plateW > 0 ? {
        x: block.plateX,
        w: block.plateW,
        y: (block.barH - block.plateH) / 2,
        h: block.plateH,
        r: block.plateR
    } : {
        x: 0,
        w: block.width,
        y: 0,
        h: block.barH,
        r: block.pillRadius
    }

    readonly property var gooShape: {
        const g = revealer.goo;
        const s1 = Math.min(1, g / 0.45);
        const s2 = Math.max(0, (g - 0.45) / 0.55);
        const fw = revealer.gooW;
        const fh = revealer.gooH;
        const fx = revealer.gooX;
        const fy = block.barH + revealer.floatGap;
        const host = block.split && block.plateW > 0;
        const cx = revealer.srcX + revealer.srcW / 2;
        const w0 = host ? Math.max(2, block.plateW - 32) : Math.min(Math.max(revealer.srcW, 24), 44);
        const h0 = host ? Math.max(2, block.plateH - 32) : Math.max(8, block.barH - 12);
        const x0 = host ? block.plateX + (block.plateW - w0) / 2 : cx - w0 / 2;
        const y0 = (block.barH - h0) / 2;
        const mw = fw * 0.8;
        const mh = fh * 0.76;
        const mx = fx + (fw - mw) / 2;
        const my = block.barH + revealer.floatGap * 0.5;
        const early = g < 0.45;
        return {
            x: early ? x0 + (mx - x0) * s1 : mx + (fx - mx) * s2,
            y: early ? y0 + (my - y0) * s1 : my + (fy - my) * s2,
            w: early ? w0 + (mw - w0) * s1 : mw + (fw - mw) * s2,
            h: early ? h0 + (mh - h0) * s1 : mh + (fh - mh) * s2,
            k: 16 * (1 - s2)
        };
    }

    property real handX: 0
    property real handW: 0
    property real handH: 0
    property string handFor: ""
    property bool gliding: false
    property real closedAt: 0

    Timer {
        id: glideEnd
        interval: M3Motion.spatialDuration("move") + 60
        onTriggered: revealer.gliding = false
    }

    function handoffSource() {
        const f = block.frame;
        if (!f || !f.visibleBlocks)
            return null;
        const now = Date.now();
        for (const b of f.visibleBlocks) {
            if (b === block || b.leaving || !b.tabOpen || b.panelKind !== "" || b.shownKind !== "")
                continue;
            if (now - b.closedAt > 120)
                continue;
            return b;
        }
        return null;
    }

    function tryHandoff() {
        const k = revealer.handFor;
        revealer.handFor = "";
        if (k === "")
            return;
        const src = revealer.handoffSource();
        if (!src)
            return;
        revealer.handX = src.absX + src.tabX - block.absX;
        revealer.handW = src.tabW;
        revealer.handH = Math.max(block.barH, src.tabHRaw);
        revealer.gliding = true;
        glideEnd.restart();
        revealer.gooSnap = true;
    }

    property string clickedKind: ""
    property string hoverKind: ""
    property string lastKind: ""
    readonly property string shownKind: contentHost ? contentHost.shownKind : ""
    property bool opening: false
    readonly property bool closing: revealer.panelKind === ""
    property bool motionClosing: true
    property string openerId: ""
    property string pendingKind: ""
    property Item pendingItem: null
    property bool pendingClicked: false
    property string pendingRevealKind: ""
    readonly property var pendingRevealSlot: revealer.pendingRevealKind === "" ? null : (contentHost && contentHost.slotA.kind === revealer.pendingRevealKind ? contentHost.slotA : contentHost ? contentHost.slotB : null)
    readonly property int pendingRevealStatus: revealer.pendingRevealSlot ? revealer.pendingRevealSlot.status : Loader.Null

    onPendingRevealStatusChanged: {
        if (revealer.pendingRevealKind === "" || revealer.pendingRevealStatus !== Loader.Ready)
            return;
        revealer.commitReveal(revealer.pendingRevealKind);
    }

    Timer {
        id: revealFallback
        interval: 150
        onTriggered: revealer.commitReveal(revealer.pendingRevealKind)
    }

    function isSys(k) {
        return k === "clipboard" || k === "wallpaper" || k === "osd";
    }

    function hostsSys(k) {
        return BarLayout.panelItemHost(k) ? layout.isPrimary && !block.leaving && block.hasItem(k) : revealer.sysHost;
    }

    readonly property string sysKind: GlobalStates.clipboardOpen && (SettingsConfig.general.clipboardPanelMode ?? "dock") !== "center" && revealer.hostsSys("clipboard") ? "clipboard" : GlobalStates.wallpaperOpen && (SettingsConfig.general.wallpaperPanelMode ?? "dock") !== "center" && revealer.hostsSys("wallpaper") ? "wallpaper" : revealer.sysHost && GlobalStates.osdOpen && BarLayout.osdHostItem === "" ? "osd" : ""

    readonly property string panelKind: revealer.launchHost && GlobalStates.launcherPreview ? "launcher" : revealer.previewHost ? GlobalStates.panelPreview : block.leaving ? "" : block.editMode ? (!GlobalStates.barEditTest ? "" : revealer.osdWant || revealer.sysKind === "osd" ? "osd" : revealer.popupWant ? "notifPopup" : "") : revealer.sysKind !== "" ? revealer.sysKind : revealer.launchHost && GlobalStates.appLauncherOpen ? "launcher" : revealer.clickedKind !== "" ? revealer.clickedKind : block.hovering && revealer.hoverKind !== "" ? revealer.hoverKind : revealer.osdWant && !revealer.popupWant && revealer.tuckHost === "" ? "osd" : revealer.popupWant && revealer.tuckHost === "" ? "notifPopup" : ""

    property int openSeq: 0
    onShownKindChanged: {
        revealer.updateCrowded();
        if (revealer.shownKind !== "" && layout.nextPanelSeq)
            revealer.openSeq = layout.nextPanelSeq();
        revealer.trackGoo();
        revealer.queueSync();
    }
    onTabXChanged: revealer.trackGoo()
    onTabWChanged: revealer.trackGoo()
    onTabHChanged: revealer.trackGoo()

    onPanelKindChanged: {
        const k = revealer.panelKind;
        if (k === "" && revealer.shownKind !== "")
            revealer.closedAt = Date.now();
        revealer.opening = k !== "" && !revealer.tabOpen;
        revealer.motionClosing = k === "";
        if (k === "launcher") {
            revealer.resyncSource();
            revealer.openerId = "";
        } else if (revealer.previewHost && k === GlobalStates.panelPreview) {
            const opener = block.itemFor(revealer.previewOpener(k));
            if (revealer.tabH <= block.barH + 0.5) {
                revealer.snapSource(opener, k);
            } else {
                revealer.sourceFrom(opener);
                revealer.flushSource(k);
            }
            revealer.openerId = "";
        } else if (k === "notifPopup" && revealer.tabH <= block.barH + 0.5) {
            revealer.anchorSource(BarLayout.popupHostItem, k);
            revealer.openerId = "";
        } else if (k === "osd" && revealer.osdHost) {
            revealer.resyncSource();
            revealer.openerId = "";
        } else if (revealer.isSys(k) && revealer.tabH <= block.barH + 0.5) {
            revealer.snapSource(BarLayout.panelItemHost(k) && block.hasItem(k) ? block.itemFor(k) : null, k);
            revealer.openerId = "";
        }
        if (k !== "")
            revealer.lastKind = k;
        revealer.stopFollow();
        if (contentHost) {
            contentHost.panelSwap = k !== "" && revealer.shownKind !== "";
            contentHost.panelKind = k;
        }
        revealer.pendingRevealKind = "";
        if (k !== "") {
            const targetSlot = contentHost ? contentHost.prepareContent(k) : null;
            if (targetSlot && targetSlot.status === Loader.Ready) {
                revealer.commitReveal(k);
            } else {
                revealer.pendingRevealKind = k;
                revealFallback.restart();
            }
        } else {
            revealer.gliding = false;
            revealer.openLocked = false;
            revealer.gooSnap = false;
            if (contentHost)
                contentHost.showContent("");
        }
    }

    function commitReveal(k) {
        revealer.pendingRevealKind = "";
        revealFallback.stop();
        if (revealer.panelKind !== k)
            return;
        if (revealer.opening) {
            revealer.handFor = k;
            revealer.tryHandoff();
        }
        revealer.openAlong = revealer.alongOf(k);
        revealer.openAcross = revealer.acrossOf(k);
        revealer.openLocked = true;
        revealer.gooSnap = false;
        if (contentHost)
            contentHost.showContent(k);
    }

    function openPanel(kind, item) {
        if (block.editMode)
            return;
        if (revealer.clickedKind === kind) {
            revealer.closePanel();
            return;
        }
        revealer.beginOpen(kind, item ?? null, true);
    }

    function closePanel() {
        revealer.pendingKind = "";
        revealer.clickedKind = "";
        revealer.hoverKind = "";
    }

    function hoverOpen(kind, item) {
        if (block.editMode || revealer.clickedKind !== "")
            return;
        if (revealer.panelKind !== "" && revealer.panelKind !== kind && !revealer.isTransient(revealer.panelKind))
            return;
        if (kind !== "dockPreview") {
            const owner = block.ownerIdOf(item ?? null);
            if (owner !== "" && !BarLayout.isGroup(owner) && BarLayout.openOn(owner) !== "hover")
                return;
        }
        if (revealer.panelKind === kind) {
            revealer.hoverKind = kind;
            return;
        }
        revealer.beginOpen(kind, item ?? null, false);
    }

    function beginOpen(kind, item, clicked) {
        if (block.editMode)
            return;
        if (revealer.tabOpen) {
            revealer.sourceFrom(item);
            revealer.flushSource(kind);
            revealer.openerId = block.slotIdOf(item);
            if (clicked) {
                revealer.clickedKind = kind;
            } else {
                revealer.clickedKind = "";
                revealer.hoverKind = kind;
            }
            return;
        }
        revealer.snapSource(item, kind);
        revealer.openerId = block.slotIdOf(item);
        if (clicked)
            revealer.clickedKind = kind;
        else
            revealer.hoverKind = kind;
    }

    function checkSettled() {
        if (tabXAnim.running || tabWAnim.running || tabHAnim.running || openTrans.running || closeTrans.running)
            return;
        if (!revealer.closing) {
            revealer.openLocked = false;
            revealer.startFollow();
            return;
        }
        if (revealer.tabH > block.barH + 0.5)
            return;
        revealer.lastKind = "";
        revealer.openerId = "";
        if (revealer.pendingKind === "")
            return;
        const k = revealer.pendingKind;
        const it = revealer.pendingItem;
        const c = revealer.pendingClicked;
        revealer.pendingKind = "";
        revealer.pendingItem = null;
        revealer.beginOpen(k, it, c);
    }

    function checkHoverLeave() {
        if (revealer.clickedKind !== "" || (revealer.launchHost && GlobalStates.appLauncherOpen))
            return;
        if (!block.hovering)
            revealer.hoverKind = "";
    }

    property real srcX: 0
    property real srcW: 0
    readonly property real srcEdgeX: revealer.snapInL(revealer.srcX) ? 0 : revealer.srcX
    readonly property real srcEdgeW: (revealer.snapInR(revealer.srcX + revealer.srcW) ? block.width : revealer.srcX + revealer.srcW) - revealer.srcEdgeX

    function sourceFrom(item) {
        block.plateFrom(item);
        if (item) {
            const r = item.mapToItem(block, 0, 0, item.width, item.height);
            revealer.srcX = r.x;
            revealer.srcW = r.width;
            return;
        }
        const ws = block.shownItemFor("workspaces");
        if (ws) {
            const r = ws.mapToItem(block, 0, 0, ws.width, ws.height);
            revealer.srcX = r.x;
            revealer.srcW = r.width;
            return;
        }
        revealer.srcX = 0;
        revealer.srcW = block.width;
    }

    function flushSource(kind) {
        const w = revealer.alongOf(kind);
        const cx = revealer.srcX + revealer.srcW / 2;
        const tx = revealer.alignX(w, cx);
        const pinned = Math.abs(tx - (cx - w / 2)) > 0.5;
        let l = revealer.srcX;
        let r = revealer.srcX + revealer.srcW;
        if (pinned && Math.abs(tx) <= 0.5)
            l = Math.min(l, 0);
        if (pinned && Math.abs(tx + w - block.width) <= 0.5)
            r = Math.max(r, block.width);
        revealer.srcX = l;
        revealer.srcW = r - l;
    }

    function snapSource(item, kind) {
        revealer.sourceFrom(item);
        revealer.flushSource(kind);
    }

    function anchorSource(id, kind) {
        const it = block.shownItemFor(id);
        if (it) {
            revealer.sourceFrom(it);
            revealer.flushSource(kind);
            return;
        }
        block.plateFrom(null);
        const w = revealer.alongOf(kind);
        revealer.srcX = revealer.alignX(w, block.width / 2);
        revealer.srcW = w;
    }

    function resyncSource() {
        const k = revealer.panelKind;
        const snap = revealer.tabH <= block.barH + 0.5;
        if (k === "osd" && revealer.osdHost) {
            revealer.anchorSource(BarLayout.osdHostItem, k);
            return;
        }
        if (k === "launcher") {
            block.plateFrom(null);
            const w = revealer.alongOf("launcher");
            const it = ServiceLauncher.position === "item" ? block.itemFor("launcher") : null;
            const cx = it ? block.centerOfItem("launcher") : block.width / 2;
            revealer.srcX = revealer.alignX(w, cx);
            revealer.srcW = w;
            return;
        }
        const item = BarLayout.panelItemHost(k) && block.hasItem(k) ? block.itemFor(k) : null;
        if (snap) {
            revealer.snapSource(item, k);
        } else {
            revealer.sourceFrom(item);
            revealer.flushSource(k);
        }
    }

    readonly property bool dockRevealing: !!block.frame && (block.frame.reveal ?? 1) < 0.999
    onDockRevealingChanged: if (!revealer.dockRevealing && (revealer.isSys(revealer.panelKind) || revealer.panelKind === "launcher"))
        revealer.resyncSource()

    Connections {
        target: block
        function onWidthChanged() {
            if ((revealer.isSys(revealer.panelKind) || revealer.panelKind === "launcher") && !revealer.dockRevealing)
                revealer.resyncSource();
        }
        function onEditModeChanged() {
            revealer.pendingKind = "";
            revealer.clickedKind = "";
            revealer.hoverKind = "";
            if (block.editMode)
                revealer.lastKind = "";
        }
    }

    function isTransient(k) {
        return k === "osd" || k === "notifPopup";
    }

    function itemOf(k) {
        return contentHost ? contentHost.itemOf(k) : null;
    }

    function heightCap(k) {
        const it = revealer.itemOf(k);
        return it && it.maxContentH !== undefined ? Math.min(revealer.heightRoom, it.maxContentH) : revealer.heightRoom;
    }

    function kindWidth(k) {
        switch (k) {
        case "weather":
            return BarLayout.panelW("weather");
        case "calendar":
            return BarLayout.panelW("calendar");
        case "musicPoster":
            return 480;
        case "musicDial":
            return 380;
        case "musicSources":
            return 440;
        case "musicBeads":
            return 540;
        case "musicDevelop":
            return 460;
        case "musicShape":
            return 440;
        case "tray":
            return 28 + revealer.trayCols * 36 + (revealer.trayCols - 1) * 6;
        case "trayMenu":
            return 260;
        case "sound":
            return 360;
        case "soundscape":
            return 360;
        case "scenes":
            return 360;
        case "network":
            return 380;
        case "bluetooth":
            return 380;
        case "brightness":
            return 340;
        case "powerMode":
            return 320;
        case "battery":
            return 400;
        case "claudeCode":
            return 400;
        case "cpu":
            return 380;
        case "memory":
            return 380;
        case "wiz":
            return 380;
        case "kindle":
            return 400;
        case "dashboard":
            return revealer.itemOf("dashboard")?.inPage ? Math.min(revealer.itemOf("dashboard").pageW, revealer.widthRoom) : Math.min(BarLayout.panelW("dashboard"), revealer.widthRoom);
        case "phoneStatus":
            return 400;
        case "phoneNotifs":
            return 420;
        case "phoneCall":
            return 400;
        case "power":
            return 360;
        case "windowInfo":
            return 360;
        case "notifPopup":
            return 380;
        case "more":
            return revealer.itemOf("more") ? revealer.itemOf("more").implicitWidth : 240;
        case "notifications":
            return 400;
        case "dockPreview":
            return revealer.dockPreviewWidth;
        case "dockMenu":
            return 210;
        case "clipboard":
            return Appearance.size.wallpaperPanelWidth;
        case "wallpaper":
            return Math.min(ServiceWallpaper.panelWidth, revealer.widthRoom);
        case "osd":
            {
                const n = Math.max(1, GlobalStates.osdKinds.length);
                return block.vertical ? 16 + n * 44 + (n - 1) * 8 : 16 + n * (n > 1 ? 220 : 284) + (n - 1) * 8;
            }
        case "launcher":
            {
                if (ServiceLauncher.position === "block" && SettingsConfig.general.launcherMatchDock === true)
                    return Math.max(block.width, ServiceLauncher.minWidth);
                return BarLayout.panelW("launcher");
            }
        }
        return 0;
    }

    function contentHeight(k) {
        switch (k) {
        case "weather":
            return BarLayout.panelHeightIn("weather", revealer.itemOf("weather") ? revealer.itemOf("weather").implicitHeight : Appearance.size.weatherPanelHeight, revealer.heightCap("weather"));
        case "calendar":
            return BarLayout.panelHeightIn("calendar", Appearance.size.calanderHeight, revealer.heightRoom);
        case "musicPoster":
            return 300;
        case "musicDial":
            return 410;
        case "musicSources":
            return 340;
        case "musicBeads":
            return 190;
        case "musicDevelop":
            return 230;
        case "musicShape":
            return 240;
        case "tray":
            return 28 + revealer.trayRows * 36 + (revealer.trayRows - 1) * 6;
        case "trayMenu":
            return revealer.itemOf("trayMenu") ? revealer.itemOf("trayMenu").implicitHeight : 160;
        case "sound":
            return revealer.itemOf("sound") ? revealer.itemOf("sound").implicitHeight : 420;
        case "soundscape":
            return revealer.itemOf("soundscape") ? revealer.itemOf("soundscape").implicitHeight : 560;
        case "scenes":
            return revealer.itemOf("scenes") ? revealer.itemOf("scenes").implicitHeight : 420;
        case "network":
            return 600;
        case "bluetooth":
            return 600;
        case "brightness":
            return revealer.itemOf("brightness") ? revealer.itemOf("brightness").implicitHeight : 150;
        case "powerMode":
            return revealer.itemOf("powerMode") ? revealer.itemOf("powerMode").implicitHeight + 28 : 316;
        case "power":
            return revealer.itemOf("power") ? revealer.itemOf("power").implicitHeight : 460;
        case "windowInfo":
            return revealer.itemOf("windowInfo") ? revealer.itemOf("windowInfo").implicitHeight : 300;
        case "notifPopup":
            return revealer.itemOf("notifPopup") ? revealer.itemOf("notifPopup").implicitHeight : 120;
        case "more":
            return revealer.itemOf("more") ? revealer.itemOf("more").implicitHeight : 120;
        case "notifications":
            return revealer.measured("notifications", 120);
        case "battery":
            return revealer.itemOf("battery") ? revealer.itemOf("battery").implicitHeight : 520;
        case "claudeCode":
            return revealer.itemOf("claudeCode") ? revealer.itemOf("claudeCode").implicitHeight : 480;
        case "cpu":
            return revealer.itemOf("cpu") ? revealer.itemOf("cpu").implicitHeight : 600;
        case "memory":
            return revealer.itemOf("memory") ? revealer.itemOf("memory").implicitHeight : 600;
        case "wiz":
            return revealer.itemOf("wiz") ? revealer.itemOf("wiz").implicitHeight : 640;
        case "kindle":
            return revealer.itemOf("kindle") ? revealer.itemOf("kindle").implicitHeight : 560;
        case "dashboard":
            return revealer.itemOf("dashboard")?.inPage ? Math.min(revealer.itemOf("dashboard").pageH, revealer.heightCap("dashboard")) : BarLayout.panelHeightIn("dashboard", revealer.itemOf("dashboard") ? revealer.itemOf("dashboard").implicitHeight : GlobalStates.dashboardHeight > 0 ? GlobalStates.dashboardHeight : 600, revealer.heightCap("dashboard"));
        case "phoneStatus":
            return revealer.itemOf("phoneStatus") ? revealer.itemOf("phoneStatus").implicitHeight : 260;
        case "phoneNotifs":
            return revealer.itemOf("phoneNotifs") ? revealer.itemOf("phoneNotifs").implicitHeight : 300;
        case "phoneCall":
            return revealer.itemOf("phoneCall") ? revealer.itemOf("phoneCall").implicitHeight : 300;
        case "dockPreview":
            return revealer.itemOf("dockPreview") ? revealer.itemOf("dockPreview").implicitHeight : 90;
        case "dockMenu":
            return revealer.itemOf("dockMenu") ? revealer.itemOf("dockMenu").implicitHeight : 150;
        case "clipboard":
            return Appearance.size.wallpaperPanelHeight;
        case "wallpaper":
            return ServiceWallpaper.panelHeight;
        case "osd":
            return block.vertical ? 280 : 64;
        case "launcher":
            return Math.max(320, Math.min(BarLayout.panelH("launcher"), revealer.heightRoom));
        }
        return 0;
    }

    function alongOf(k) {
        return block.vertical ? revealer.contentHeight(k) : revealer.kindWidth(k);
    }

    function acrossOf(k) {
        return block.vertical ? revealer.kindWidth(k) : revealer.contentHeight(k);
    }

    readonly property string animKind: revealer.motionClosing ? revealer.lastKind : revealer.panelKind
    readonly property bool panelMotion: revealer.animKind !== ""
    readonly property bool quickMotion: revealer.panelMotion && revealer.isTransient(revealer.animKind)
    readonly property bool caeStyle: !revealer.merged && !revealer.floating && !revealer.drawer
    readonly property bool caeMotion: revealer.caeStyle && revealer.panelMotion && !revealer.quickMotion
    readonly property var caeCurve: [0.38, 1.21, 0.22, 1.0, 1, 1]
    readonly property int sizeDuration: revealer.gliding ? M3Motion.spatialDuration("move") : revealer.caeMotion ? 500 : revealer.drawer && revealer.panelMotion ? M3Motion.spatialDuration("default") : revealer.quickMotion ? (revealer.motionClosing ? 240 : 380) : revealer.panelMotion && !revealer.motionClosing ? M3Motion.panel.openDuration : M3Motion.spatialDuration("fast")
    readonly property var sizeCurve: revealer.gliding ? M3Motion.spatialCurve("move") : !revealer.panelMotion ? M3Motion.spatialCurve("fast") : revealer.caeMotion ? revealer.caeCurve : revealer.drawer ? M3Motion.spatialCurve("default") : revealer.quickMotion ? (revealer.motionClosing ? [0.3, 0.0, 1.0, 1.0, 1, 1] : [0.05, 0.7, 0.1, 1.0, 1, 1]) : revealer.motionClosing ? M3Motion.panel.closeCurve : M3Motion.panel.openCurve

    readonly property int spanDuration: revealer.panelMotion && revealer.motionClosing && !revealer.quickMotion && !revealer.drawer && !revealer.caeMotion ? M3Motion.panel.closeDuration : revealer.sizeDuration
    readonly property var spanCurve: revealer.sizeCurve
    readonly property int dropDuration: revealer.spanDuration
    readonly property var dropCurve: revealer.sizeCurve

    readonly property real snapReach: block.frame && block.frame.tabPullFor ? block.frame.tabPullFor(block) : revealer.panelCorner

    function snapInL(x) {
        return x > 0.5 && x < revealer.snapReach && block.absX >= block.spanL - 0.5;
    }

    function snapInR(r) {
        const g = block.width - r;
        return g > 0.5 && g < revealer.snapReach && block.absX + block.width <= block.spanR + 0.5;
    }

    readonly property real tabNaturalW: revealer.openLocked ? revealer.openAlong : revealer.alongOf(revealer.shownKind)

    function mergedSnap(x, w) {
        if (!revealer.merged)
            return x;
        const reach = revealer.snapReach;
        const sl = block.spanL - block.absX;
        const sr = block.spanR - block.absX - w;
        let s = x;
        if (x < -0.5 && x > -reach)
            s = 0;
        else if (x + w > block.width + 0.5 && x + w < block.width + reach)
            s = block.width - w;
        return s >= sl - 0.5 && s <= sr + 0.5 ? s : x;
    }

    readonly property var bodyMap: block.frame && block.frame.panelBodies ? block.frame.panelBodies : ({})
    readonly property bool avoids: !block.editMode && !!block.frame && !!block.frame.obstaclesFor
    readonly property var obstacles: revealer.avoids ? block.frame.obstaclesFor(block.blockId, revealer.bodyMap, revealer.isTransient(revealer.shownKind)) : []
    readonly property var transientObstacles: revealer.avoids ? block.frame.obstaclesFor(block.blockId, revealer.bodyMap, true) : []
    readonly property real panelGap: 16

    function avoidX(x, w, obs, loose) {
        if (!obs.length)
            return {
                x: x,
                ok: true,
                host: ""
            };
        const corner = revealer.floating ? 0 : revealer.panelCorner;
        const sl = block.spanL - block.absX + revealer.sideInset;
        const sr = block.spanR - block.absX - w - revealer.sideInset;
        const minOverlap = loose ? -Infinity : Math.min(24, block.width / 2);
        const fits = cx => {
            if (cx < sl - 0.5 || cx > sr + 0.5)
                return false;
            const L = revealer.snapInL(cx) ? 0 : cx;
            const R = revealer.snapInR(cx + w) ? block.width : cx + w;
            if (Math.min(R, block.width) - Math.max(L, 0) < minOverlap)
                return false;
            for (const o of obs) {
                const lo = o.l - block.absX;
                const ro = o.r - block.absX;
                if ((lo + ro) / 2 >= (L + R) / 2) {
                    const need = o.gap ?? revealer.panelGap + (R < block.width - 0.5 ? corner : 0) + (o.il ? corner : 0);
                    if (lo - R < need)
                        return false;
                } else {
                    const need = o.gap ?? revealer.panelGap + (L > 0.5 ? corner : 0) + (o.ir ? corner : 0);
                    if (L - ro < need)
                        return false;
                }
            }
            return true;
        };
        if (fits(x))
            return {
                x: x,
                ok: true,
                host: ""
            };
        const cands = [];
        for (const o of obs) {
            const lo = o.l - block.absX;
            const ro = o.r - block.absX;
            const g = o.gap ?? revealer.panelGap;
            for (const extra of [0, corner, 2 * corner]) {
                cands.push(ro + g + extra);
                cands.push(lo - g - extra - w);
            }
        }
        cands.sort((a, b) => Math.abs(a - x) - Math.abs(b - x));
        for (const c of cands) {
            if (fits(c))
                return {
                    x: c,
                    ok: true,
                    host: ""
                };
        }
        let host = "";
        let best = 0;
        for (const o of obs) {
            if (o.transient)
                continue;
            const ov = Math.min(x + w, o.r - block.absX) - Math.max(x, o.l - block.absX);
            if (host === "" || ov > best) {
                host = o.id;
                best = ov;
            }
        }
        return {
            x: x,
            ok: false,
            host: host
        };
    }

    readonly property real sideInset: revealer.floating ? revealer.panelGapSetting : 0

    function alignX(w, cx) {
        const x = cx - w / 2;
        const sl = block.spanL - block.absX + revealer.sideInset;
        const sr = block.spanR - block.absX - w - revealer.sideInset;
        if (w <= block.width) {
            const bl = Math.max(0, sl);
            const br = Math.min(block.width - w, sr);
            if (bl <= br)
                return Math.max(bl, Math.min(br, x));
        }
        if (sr < sl)
            return Math.max(Math.min(sl, block.spanF - block.absX), sr);
        return Math.max(sl, Math.min(sr, x));
    }

    readonly property real tabBaseX: {
        const w = revealer.tabNaturalW;
        const x = revealer.mergedSnap(revealer.alignX(w, revealer.srcX + revealer.srcW / 2), w);
        if (revealer.obstacles.length === 0)
            return x;
        return revealer.avoidX(x, w, revealer.obstacles).x;
    }
    readonly property var crossObstacles: !block.vertical && !block.editMode && revealer.shownKind !== "" && block.frame && block.frame.crossFor ? block.frame.crossFor(block) : []
    readonly property real pushShift: block.frame && block.frame.pushPlan ? (block.frame.pushPlan.shift[block.blockId] ?? 0) : 0
    readonly property real tabNaturalX: revealer.tabPreX + revealer.pushShift
    readonly property real tabPreX: revealer.crossObstacles.length === 0 ? revealer.tabBaseX : revealer.avoidX(revealer.tabBaseX, revealer.tabNaturalW, revealer.obstacles.concat(revealer.crossObstacles), revealer.floating).x

    readonly property string transientWant: revealer.popupWant ? "notifPopup" : revealer.osdWant ? "osd" : ""
    readonly property string tuckHost: {
        const k = revealer.transientWant;
        if (k === "" || revealer.transientObstacles.length === 0)
            return "";
        const w = revealer.kindWidth(k);
        const cx = block.centerOfItem(k === "osd" ? BarLayout.osdHostItem : BarLayout.popupHostItem);
        const x = revealer.mergedSnap(revealer.alignX(w, cx), w);
        const r = revealer.avoidX(x, w, revealer.transientObstacles);
        return r.ok ? "" : r.host;
    }

    readonly property bool selfTuck: revealer.transientWant !== "" && revealer.shownKind !== "" && !revealer.isTransient(revealer.shownKind) && !revealer.closing
    readonly property var tuckers: {
        if (revealer.shownKind === "" || revealer.closing)
            return [];
        const out = revealer.selfTuck ? [block] : [];
        if (block.frame && block.frame.visibleBlocks)
            for (const b of block.frame.visibleBlocks)
                if (b !== block && b.tuckHost === block.blockId)
                    out.push(b);
        return out;
    }
    readonly property bool tuckPopup: revealer.tuckers.some(b => b.popupWant)
    readonly property bool tuckOsd: revealer.tuckers.some(b => b.osdWant)
    readonly property real tuckH: contentHost && contentHost.tuckRow && contentHost.tuckRow.item ? (revealer.tuckPopup ? contentHost.tuckRow.item.implicitHeight : 60) : 0
    property real tuckShown: revealer.tuckH
    Behavior on tuckShown {
        SpatialAnim {
            speed: "fast"
        }
    }

    function syncBody() {
        if (!block.frame || !block.frame.setBody)
            return;
        if (revealer.shownKind === "" || revealer.closing || block.editMode) {
            block.frame.clearBody(block.blockId);
            return;
        }
        const fil = !revealer.floating;
        block.frame.setBody(block.blockId, block.absX + revealer.tabTargetX, block.absX + revealer.tabTargetX + revealer.tabTargetW, fil && revealer.tabTargetX > 0.5, fil && revealer.tabTargetX + revealer.tabTargetW < block.width - 0.5, revealer.isTransient(revealer.shownKind));
    }
    function queueSync() {
        revealer.syncBody();
    }
    onTabTargetXChanged: revealer.queueSync()
    onTabTargetWChanged: revealer.queueSync()
    onClosingChanged: revealer.queueSync()
    Connections {
        target: block
        function onAbsXChanged() {
            revealer.queueSync();
        }
    }
    Component.onDestruction: if (block.frame && block.frame.clearBody)
        block.frame.clearBody(block.blockId)

    property bool heightFollow: false
    property bool followLock: false
    property real followAcross: 0
    Behavior on followAcross {
        enabled: revealer.heightFollow
        SpringAnimation {
            spring: M3Motion.spring.responsive.spring
            damping: M3Motion.spring.responsive.damping
            epsilon: 0.25
        }
    }
    readonly property real liveAcross: revealer.shownKind !== "" ? revealer.acrossOf(revealer.shownKind) + revealer.tuckShown : 0
    onLiveAcrossChanged: {
        if (!revealer.heightFollow)
            return;
        revealer.followAcross = revealer.liveAcross;
        revealer.rememberHeight();
    }

    function startFollow() {
        if (revealer.heightFollow || revealer.shownKind === "" || revealer.closing)
            return;
        revealer.followLock = true;
        revealer.followAcross = revealer.liveAcross;
        revealer.heightFollow = true;
        revealer.rememberHeight();
    }

    readonly property var memoKinds: ["notifications"]
    property var heightMemo: ({})

    function measured(k, fallback) {
        const it = revealer.itemOf(k);
        if (revealer.memoKinds.indexOf(k) >= 0 && !(revealer.heightFollow && revealer.shownKind === k)) {
            const m = revealer.heightMemo[k];
            if (m !== undefined)
                return m;
        }
        return it ? it.implicitHeight : fallback;
    }

    function rememberHeight() {
        const k = revealer.shownKind;
        if (!revealer.heightFollow || revealer.memoKinds.indexOf(k) < 0)
            return;
        const it = revealer.itemOf(k);
        if (!it || revealer.heightMemo[k] === it.implicitHeight)
            return;
        const m = Object.assign({}, revealer.heightMemo);
        m[k] = it.implicitHeight;
        revealer.heightMemo = m;
    }

    function stopFollow() {
        if (!revealer.heightFollow)
            return;
        revealer.followLock = false;
        revealer.heightFollow = false;
    }

    readonly property int trayCount: ServiceSystemTray.items ? ServiceSystemTray.items.values.length : 0
    property int trayOffset: 0
    readonly property int trayHidden: Math.max(0, revealer.trayCount - revealer.trayOffset)
    readonly property int trayCols: Math.max(1, Math.min(6, revealer.trayHidden))
    readonly property int trayRows: Math.max(1, Math.ceil(revealer.trayHidden / 6))
    property var trayMenuItem: null
    readonly property bool trayMenuAlive: revealer.trayMenuItem !== null && ServiceSystemTray.items && ServiceSystemTray.items.values.indexOf(revealer.trayMenuItem) >= 0

    onTrayMenuAliveChanged: if (!revealer.trayMenuAlive && revealer.panelKind === "trayMenu")
        revealer.closePanel()
    onTrayHiddenChanged: if (revealer.trayHidden === 0 && revealer.panelKind === "tray")
        revealer.closePanel()

    function openTrayOverflow(source, limit, clicked) {
        if (revealer.panelKind !== "tray")
            revealer.trayOffset = Math.max(0, limit);
        if (clicked)
            revealer.openPanel("tray", source);
        else
            revealer.hoverOpen("tray", source);
    }

    function openTrayMenu(trayItem, source) {
        if (block.editMode || !trayItem)
            return;
        if (revealer.panelKind === "trayMenu" && revealer.trayMenuItem === trayItem) {
            revealer.closePanel();
            return;
        }
        revealer.trayMenuItem = trayItem;
        if (!source && revealer.panelKind === "tray") {
            revealer.clickedKind = "trayMenu";
            return;
        }
        revealer.beginOpen("trayMenu", source, true);
    }

    property string dockAppId: ""
    readonly property var dockAppEntry: {
        if (revealer.dockAppId === "")
            return null;
        const want = revealer.dockAppId.toLowerCase();
        return ServiceApps.dockModel.find(e => (e.appId ?? "").toLowerCase() === want) ?? null;
    }
    readonly property int dockWinCount: revealer.dockAppEntry ? revealer.dockAppEntry.toplevels.length : 0
    readonly property real dockPreviewCap: block.vertical ? Math.min(300, revealer.widthRoom) : Math.min(Math.max(block.width, 236), revealer.widthRoom)
    readonly property real dockPreviewWidth: Math.min(300, revealer.dockPreviewCap)

    onDockAppEntryChanged: revealer.checkDockApp()
    onDockWinCountChanged: revealer.checkDockApp()

    function checkDockApp() {
        if (revealer.panelKind === "dockMenu" && !revealer.dockAppEntry)
            revealer.closePanel();
        else if (revealer.panelKind === "dockPreview" && revealer.dockWinCount === 0)
            revealer.hoverKind = "";
    }

    function appEntered(entry, item) {
        if (block.editing || !entry)
            return;
        dockLeaveTimer.stop();
        if (revealer.panelKind === "dockMenu" || revealer.clickedKind !== "")
            return;
        if (entry.toplevels.length === 0) {
            if (revealer.panelKind === "dockPreview")
                revealer.hoverKind = "";
            return;
        }
        revealer.dockAppId = entry.appId ?? "";
        if (revealer.panelKind === "dockPreview") {
            revealer.sourceFrom(item);
            revealer.hoverKind = "dockPreview";
            return;
        }
        revealer.hoverOpen("dockPreview", item);
    }

    function appExited() {
        if (revealer.panelKind === "dockPreview")
            dockLeaveTimer.restart();
    }

    function appMenu(entry, item) {
        if (block.editing || !entry)
            return;
        dockLeaveTimer.stop();
        if (revealer.panelKind === "dockMenu" && revealer.dockAppId === (entry.appId ?? "")) {
            revealer.closePanel();
            return;
        }
        revealer.dockAppId = entry.appId ?? "";
        if (revealer.panelKind === "dockPreview" || revealer.panelKind === "dockMenu") {
            revealer.sourceFrom(item);
            revealer.clickedKind = "dockMenu";
            return;
        }
        revealer.beginOpen("dockMenu", item, true);
    }

    Timer {
        id: dockLeaveTimer
        interval: 140
        onTriggered: {
            if (revealer.panelKind === "dockPreview" && !tabHover.hovered)
                revealer.hoverKind = "";
        }
    }

    Connections {
        target: GlobalStates
        function onPanelRequested(kind) {
            if (kind === "") {
                if (revealer.clickedKind !== "")
                    revealer.closePanel();
                return;
            }
            const id = BarLayout.panelHostItem(kind);
            if (!layout.isPrimary || !block.hasItem(id) || revealer.clickedKind === kind)
                return;
            const it = block.itemFor(id);
            if (it)
                revealer.openPanel(kind, it);
        }
    }

    readonly property bool panelHeld: {
        const it = revealer.itemOf(revealer.panelKind);
        return !!it && ((it.holdOpen ?? false) || (it.passwordPrompt ?? false));
    }

    readonly property var outsideCloseKinds: ["sound", "network", "bluetooth", "brightness", "powerMode", "power", "windowInfo", "battery", "phoneStatus", "phoneNotifs", "phoneCall", "soundscape", "scenes", "notifications", "weather", "claudeCode", "kindle", "dashboard", "calendar", "more", "musicPoster", "musicDial", "musicSources", "musicBeads", "musicDevelop", "musicShape", "cpu", "memory", "wiz"]

    HyprlandFocusGrab {
        windows: [QsWindow.window]
        active: !GlobalStates.capturing && (revealer.panelKind === "trayMenu" || revealer.panelKind === "dockMenu" || (revealer.outsideCloseKinds.indexOf(revealer.panelKind) >= 0 && revealer.clickedKind === revealer.panelKind && !revealer.panelHeld) || (revealer.panelKind === "tray" && revealer.clickedKind === "tray") || ((revealer.panelKind === "clipboard" || revealer.panelKind === "wallpaper") && revealer.sysKind === revealer.panelKind && !revealer.panelHeld && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen))
        onCleared: {
            if (revealer.panelHeld || GlobalStates.capturing)
                return;
            if (revealer.sysKind === "clipboard" && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen) {
                GlobalStates.clipboardOpen = false;
                return;
            }
            if (revealer.sysKind === "wallpaper" && !GlobalStates.panelHold && !GlobalStates.fileDialogOpen) {
                GlobalStates.wallpaperOpen = false;
                return;
            }
            if (["trayMenu", "dockMenu", "tray"].indexOf(revealer.panelKind) >= 0 || revealer.outsideCloseKinds.indexOf(revealer.panelKind) >= 0)
                revealer.closePanel();
        }
    }

    Behavior on tabX {
        enabled: !block.resizing && revealer.state === "open" && !openTrans.running && !closeTrans.running
        NumberAnimation {
            id: tabXAnim
            duration: revealer.spanDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: revealer.spanCurve
            onRunningChanged: if (!running)
                revealer.checkSettled()
        }
    }
    Behavior on tabW {
        enabled: !block.resizing && revealer.state === "open" && !openTrans.running && !closeTrans.running
        NumberAnimation {
            id: tabWAnim
            duration: revealer.spanDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: revealer.spanCurve
            onRunningChanged: if (!running)
                revealer.checkSettled()
        }
    }
    Behavior on tabHRaw {
        enabled: !block.resizing && !revealer.followLock && revealer.state === "open" && !openTrans.running && !closeTrans.running
        NumberAnimation {
            id: tabHAnim
            duration: revealer.dropDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: revealer.dropCurve
            onRunningChanged: if (!running)
                revealer.checkSettled()
        }
    }

    property real contentT: 0

    state: (revealer.shownKind !== "" || (revealer.launchHost && GlobalStates.appLauncherOpen)) ? "open" : "closed"
    states: [
        State {
            name: "closed"
            PropertyChanges {
                target: revealer
                tabX: revealer.gliding ? revealer.handX : revealer.srcEdgeX
                tabW: revealer.gliding ? revealer.handW : revealer.srcEdgeW
                tabHRaw: revealer.gliding ? revealer.handH : block.barH
                contentT: 0
            }
        },
        State {
            name: "open"
            PropertyChanges {
                target: revealer
                tabX: revealer.tabTargetX
                tabW: revealer.tabTargetW
                tabHRaw: block.barH + (revealer.heightFollow ? revealer.followAcross : (revealer.openLocked ? revealer.openAcross : revealer.acrossOf(revealer.shownKind)) + revealer.tuckShown)
                contentT: 1
            }
        }
    ]
    transitions: [
        Transition {
            id: openTrans
            from: "closed"
            to: "open"
            NumberAnimation {
                properties: "tabX,tabW"
                duration: revealer.spanDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: revealer.spanCurve
            }
            NumberAnimation {
                properties: "tabHRaw,contentT"
                duration: revealer.dropDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: revealer.dropCurve
            }
            onRunningChanged: if (!running)
                revealer.checkSettled()
        },
        Transition {
            id: closeTrans
            from: "open"
            to: "closed"
            NumberAnimation {
                properties: "tabX,tabW"
                duration: revealer.spanDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: revealer.spanCurve
            }
            NumberAnimation {
                properties: "tabHRaw,contentT"
                duration: revealer.dropDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: revealer.dropCurve
            }
            onRunningChanged: if (!running)
                revealer.checkSettled()
        }
    ]

    x: Math.round(block.absX + revealer.tabX) - block.absX
    y: block.far ? block.barH - Math.round(revealer.tabH) - revealer.floatGap : 0
    width: Math.round(block.absX + revealer.tabX + revealer.tabW) - Math.round(block.absX + revealer.tabX)
    height: Math.round(revealer.tabH) + revealer.floatGap
    visible: revealer.tabOpen || revealer.state === "open" || openTrans.running || closeTrans.running
    clip: true

    HoverHandler {
        id: tabHover
        onHoveredChanged: if (!hovered)
            revealer.checkHoverLeave()
    }

    Item {
        id: clipItem
        x: 0
        y: block.far ? 0 : block.barH + revealer.floatGap
        opacity: revealer.contentT
        width: revealer.width
        height: Math.max(0, revealer.height - block.barH - revealer.floatGap)
        clip: true
        layer.enabled: revealer.tabMoving && revealer.panelCorner > 0
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: panelCornerMask
        }
    }

    Rectangle {
        id: panelCornerMask
        layer.enabled: true
        readonly property real r: Math.min(revealer.panelCorner, width / 2, height / 2)
        visible: false
        width: clipItem.width
        height: clipItem.height
        color: "white"
        topLeftRadius: block.far || revealer.floating || revealer.merged ? panelCornerMask.r : 0
        topRightRadius: block.far || revealer.floating || revealer.merged ? panelCornerMask.r : 0
        bottomLeftRadius: block.far && !revealer.floating && !revealer.merged ? 0 : panelCornerMask.r
        bottomRightRadius: block.far && !revealer.floating && !revealer.merged ? 0 : panelCornerMask.r
    }
}
