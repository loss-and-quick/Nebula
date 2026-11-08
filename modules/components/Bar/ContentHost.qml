import Quickshell
import QtQuick
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom

Item {
    id: contentHost

    required property Item block
    required property Item revealer

    property string panelKind: ""
    property string shownKind: ""
    property string residentKind: ""
    property bool panelSwap: false
    readonly property var warmKinds: ["calendar", "weather"]

    property int curSlot: 0
    readonly property Item curSlotItem: curSlot === 0 ? slotA : slotB
    readonly property alias slotA: slotA
    readonly property alias slotB: slotB
    readonly property alias tuckRow: tuckRow

    anchors.fill: parent

    function itemOf(k) {
        if (slotA.kind === k && slotA.item)
            return slotA.item;
        if (slotB.kind === k && slotB.item)
            return slotB.item;
        return null;
    }

    function preload(k) {
        if (k === "" || block.editMode || revealer.kindWidth(k) <= 0 || slotA.kind === k || slotB.kind === k)
            return;
        const cur = curSlot === 0 ? slotA : slotB;
        const other = curSlot === 0 ? slotB : slotA;
        const idle = s => !s.shown && s.opacity < 0.02;
        const target = idle(other) ? other : idle(cur) ? cur : null;
        if (target)
            target.kind = k;
    }

    function prepare(k) {
        return prepareContent(k);
    }

    function prepareContent(k) {
        const cur = curSlot === 0 ? slotA : slotB;
        const other = curSlot === 0 ? slotB : slotA;
        if (cur.kind === k)
            return cur;
        if (other.kind === k)
            return other;
        const target = cur.kind === "" || (!cur.shown && cur.opacity < 0.02) ? cur : other;
        target.kind = k;
        return target;
    }

    function show(k) {
        showContent(k);
    }

    function showContent(k) {
        if (k !== "")
            residentKind = k;
        const cur = curSlot === 0 ? slotA : slotB;
        const other = curSlot === 0 ? slotB : slotA;
        if (k === "") {
            cur.shown = false;
            other.shown = false;
            shownKind = "";
            return;
        }
        shownKind = k;
        if (cur.kind === k) {
            cur.shown = true;
            other.shown = false;
            return;
        }
        if (other.kind === k) {
            other.shown = true;
            cur.shown = false;
            curSlot = 1 - curSlot;
            return;
        }
        if (cur.kind === "" || (!cur.shown && cur.opacity < 0.02)) {
            cur.kind = k;
            cur.shown = true;
            other.shown = false;
            return;
        }
        other.kind = k;
        other.shown = true;
        cur.shown = false;
        curSlot = 1 - curSlot;
    }

    Timer {
        interval: 6000
        running: true
        onTriggered: {
            if (!layout.isPrimary || !block.visible || block.width <= 0)
                return;
            if (block.osdHost) {
                contentHost.residentKind = "osd";
                contentHost.preload("osd");
                return;
            }
            const ids = block.itemIds ?? [];
            for (let i = 0; i < ids.length; i++) {
                const k = BarLayout.panelFor(ids[i]);
                if (contentHost.warmKinds.indexOf(k) >= 0) {
                    contentHost.residentKind = k;
                    contentHost.preload(k);
                    return;
                }
            }
        }
    }

    component PanelSlot: Loader {
        id: slot

        property string kind: ""
        property bool shown: false
        readonly property real fw: block.vertical ? slot.height : slot.width
        readonly property real fh: block.vertical ? slot.width : slot.height
        readonly property real slideY: block.far ? Math.max(0, contentHost.height - slot.fh) : Math.min(0, contentHost.height - slot.fh)
        readonly property real pinY: block.far ? contentHost.height - slot.fh - block.tuckShown : block.tuckShown
        property real reveal: 1
        property real drift: 0
        property bool quiet: false
        property bool ride: false
        readonly property real rideY: block.far ? Math.max(0, slot.pinY) : Math.min(slot.pinY, contentHost.height - slot.fh)

        function enter() {
            if (!slot.shown)
                return;
            if (slot.quiet) {
                revealAnim.stop();
                slot.reveal = 1;
                slot.drift = 0;
                return;
            }
            if (slot.status !== Loader.Ready) {
                revealAnim.stop();
                slot.reveal = 0;
                slot.drift = 14;
                return;
            }
            slot.reveal = 0;
            slot.drift = 14;
            revealAnim.restart();
        }

        onLoaded: slot.enter()

        ParallelAnimation {
            id: revealAnim
            SequentialAnimation {
                PauseAnimation {
                    duration: 40
                }
                NumberAnimation {
                    target: slot
                    property: "reveal"
                    to: 1
                    duration: 480
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 30
                }
                NumberAnimation {
                    target: slot
                    property: "drift"
                    to: 0
                    duration: 520
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
                }
            }
        }

        layer.enabled: slot.reveal < 1 && slot.visible
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: wipe
        }

        Item {
            id: wipe
            layer.enabled: true
            visible: false
            width: slot.width
            height: slot.height

            Rectangle {
                id: wipeEdge
                readonly property real feather: 48
                readonly property real span: wipe.height + feather
                width: wipe.width
                height: span
                y: block.far ? (1 - slot.reveal) * span - feather : (slot.reveal - 1) * span
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: block.far ? "transparent" : "white"
                    }
                    GradientStop {
                        position: block.far ? wipeEdge.feather / wipeEdge.span : 1 - wipeEdge.feather / wipeEdge.span
                        color: "white"
                    }
                    GradientStop {
                        position: 1
                        color: block.far ? "white" : "transparent"
                    }
                }
            }
        }
        transform: block.vertical ? [slotFlip] : []

        Matrix4x4 {
            id: slotFlip
            matrix: Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        onShownChanged: {
            if (slot.shown) {
                slotCache.stop();
                slot.quiet = contentHost.panelSwap || revealer.caeStyle;
                slot.ride = revealer.caeStyle && !contentHost.panelSwap;
                slot.enter();
            } else {
                slotCache.restart();
                slot.ride = revealer.caeStyle && contentHost.shownKind === "";
            }
        }

        width: block.vertical ? revealer.contentHeight(slot.kind) : revealer.kindWidth(slot.kind)
        height: block.vertical ? revealer.kindWidth(slot.kind) : revealer.contentHeight(slot.kind)

        x: Math.round((revealer.tabW - slot.fw) / 2)
        y: Math.round(slot.ride ? slot.rideY : slot.shown ? slot.pinY + (block.far ? slot.drift : -slot.drift) : slot.slideY)
        active: slot.kind !== ""
        opacity: slot.shown ? 1 : 0
        visible: slot.opacity > 0.01
        z: slot.shown ? 1 : 0

        Timer {
            id: slotCache
            interval: 30000
            onTriggered: if (!slot.shown && slot.kind !== contentHost.residentKind)
                slot.kind = ""
        }

        Behavior on opacity {
            enabled: slot.opacity > 0.5 || revealer.caeStyle
            EffectsAnim {
                speed: "default"
            }
        }

        sourceComponent: block.panels.forKind(slot.kind)
    }

    PanelSlot {
        id: slotA
    }
    PanelSlot {
        id: slotB
    }

    Loader {
        id: tuckRow
        active: block.tuckPopup || block.tuckOsd
        x: block.tuckPopup ? 0 : 12
        width: block.tuckPopup ? contentHost.width : contentHost.width - 24
        y: block.far ? contentHost.height - block.tuckShown + (block.tuckPopup ? 0 : 12) : (block.tuckPopup ? 0 : 12) - (block.tuckH - block.tuckShown)
        opacity: block.tuckH > 0 ? Math.max(0, Math.min(1, block.tuckShown / block.tuckH)) : 0
        sourceComponent: block.tuckPopup ? block.panels.tuckPopup : block.panels.tuckOsd
    }
}
