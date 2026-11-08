import "./editor"
import Quickshell
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.custom

Item {
    id: blockEditor

    required property Item block
    property Item revealer: null

    property bool resizing: false
    property string resizeKind: ""
    readonly property string sizeKind: !block.editing ? "" : block.launchHost && GlobalStates.launcherPreview && block.shownKind === "launcher" ? "launcher" : block.previewHost && block.shownKind === GlobalStates.panelPreview && !!BarLayout.panelSpecs[block.shownKind] && !BarLayout.panelSpecs[block.shownKind].fitOnly ? block.shownKind : ""
    readonly property bool sizeHandles: blockEditor.sizeKind !== "" && (blockEditor.resizing || (!revealer || !revealer.tabMoving))
    readonly property real tabContentTop: block.far ? block.barH - (revealer ? revealer.tabH : 0) - block.floatGap : block.barH + block.floatGap
    readonly property real tabContentH: revealer ? Math.max(0, revealer.tabH - block.barH) : 0
    readonly property bool flushL: revealer ? Math.abs(revealer.tabX - (block.spanL - block.absX)) <= 0.5 : false
    readonly property bool flushR: revealer ? Math.abs(revealer.tabX + revealer.tabW - (block.spanR - block.absX)) <= 0.5 : false

    function heightCap(k) {
        const it = block.itemOf(k);
        return it && it.maxContentH !== undefined ? Math.min(block.heightRoom, it.maxContentH) : block.heightRoom;
    }

    function beginResize() {
        const k = blockEditor.sizeKind;
        blockEditor.resizing = true;
        blockEditor.resizeKind = k;
        BarLayout.setDraft(k, BarLayout.panelW(k), Math.round(block.contentHeight(k)));
    }

    function updateResize(w, h) {
        const k = blockEditor.resizeKind;
        const d = BarLayout.draftOf(k);
        if (!d)
            return;
        BarLayout.setDraft(k, w === undefined ? d.w : BarLayout.clampPanelW(k, w), h === undefined ? d.h : Math.min(blockEditor.heightCap(k), BarLayout.clampPanelH(k, Math.max(0, h))));
    }

    function endResize() {
        const k = blockEditor.resizeKind;
        const d = BarLayout.draftOf(k);
        blockEditor.resizing = false;
        if (d)
            BarLayout.setPanelSize(k, d.w, d.h);
    }

    component ResizeHandle: MouseArea {
        id: handle
        property string side: "left"
        readonly property bool vertical: handle.side === "left" || handle.side === "right"
        property real startW: 0
        property real anchorX: 0
        property bool centred: true

        z: 60
        width: handle.vertical ? 16 : 72
        height: handle.vertical ? 72 : 16
        hoverEnabled: true
        preventStealing: true
        cursorShape: handle.vertical !== block.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor

        onPressed: mouse => {
            blockEditor.beginResize();
            handle.centred = !blockEditor.flushL && !blockEditor.flushR;
            handle.anchorX = handle.centred ? (revealer.tabX + revealer.tabW / 2) : blockEditor.flushR ? (revealer.tabX + revealer.tabW) : revealer.tabX;
        }
        onPositionChanged: mouse => {
            if (!handle.pressed)
                return;
            const p = handle.mapToItem(block, mouse.x, mouse.y);
            if (handle.vertical) {
                const d = Math.abs(p.x - handle.anchorX);
                const along = handle.centred ? d * 2 : d;
                if (block.vertical)
                    blockEditor.updateResize(undefined, along);
                else
                    blockEditor.updateResize(along, undefined);
            } else {
                const across = block.far ? -p.y : p.y - block.barH;
                if (block.vertical)
                    blockEditor.updateResize(across, undefined);
                else
                    blockEditor.updateResize(undefined, across);
            }
        }
        onReleased: blockEditor.endResize()
        onCanceled: blockEditor.endResize()

        Rectangle {
            anchors.centerIn: parent
            width: handle.vertical ? 5 : (handle.containsMouse || handle.pressed ? 56 : 44)
            height: handle.vertical ? (handle.containsMouse || handle.pressed ? 56 : 44) : 5
            radius: 2.5
            color: handle.pressed ? Colors.primary : handle.containsMouse ? Qt.alpha(Colors.primary, 0.85) : Qt.alpha(Colors.outline, 0.9)
            Behavior on width {
                SpatialAnim {
                    speed: "fast"
                }
            }
            Behavior on height {
                SpatialAnim {
                    speed: "fast"
                }
            }
            Behavior on color {
                EffectsColorAnim {}
            }
        }
    }

    Item {
        id: sizeChrome
        z: 45
        visible: blockEditor.sizeHandles
        opacity: blockEditor.sizeHandles ? 1 : 0
        x: revealer ? revealer.tabX : 0
        y: blockEditor.tabContentTop
        width: revealer ? revealer.tabW : 0
        height: blockEditor.tabContentH

        ResizeHandle {
            side: "left"
            visible: !blockEditor.flushL
            x: 0
            anchors.verticalCenter: parent.verticalCenter
        }
        ResizeHandle {
            side: "right"
            visible: !blockEditor.flushR
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
        }
        ResizeHandle {
            side: block.far ? "top" : "bottom"
            anchors.horizontalCenter: parent.horizontalCenter
            y: block.far ? 0 : parent.height - height
        }

        Rectangle {
            id: sizeBubble
            visible: blockEditor.resizing
            anchors.centerIn: parent
            width: sizeLabel.implicitWidth + 24
            height: 32
            radius: 16
            color: Colors.inverseSurface
            transform: block.vertical ? [sizeFlip] : []

            Matrix4x4 {
                id: sizeFlip
                matrix: block.flipAbout(sizeBubble.width, sizeBubble.height)
            }

            CustomText {
                id: sizeLabel
                anchors.centerIn: parent
                readonly property var draft: BarLayout.draftOf(blockEditor.resizeKind)
                content: draft ? draft.w + " × " + Math.round(draft.h) : ""
                size: 13
                weight: 700
                customColor: Colors.inverseSurfaceText
                font.features: {
                    "tnum": 1
                }
            }
        }
    }

    Shape {
        z: 40
        x: 0
        y: 0
        width: block.width
        height: block.barH
        visible: block.revealT > 0.001 && BarLayout.gapDragT < 0.999
        opacity: block.revealT * (1 - BarLayout.gapDragT)
        layer.enabled: visible
        layer.samples: 4

        ShapePath {
            strokeColor: block.blockSelected && BarLayout.gapModel ? "transparent" : Colors.primary
            strokeWidth: block.isDropTarget || block.blockSelected ? 2 : 1.5
            strokeStyle: block.blockSelected ? ShapePath.SolidLine : ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: Qt.alpha(Colors.primary, block.isDropTarget ? 0.16 : 0.06)

            PathRectangle {
                x: 2
                y: 3
                width: Math.max(0, block.width - 4)
                height: block.barH - 6
                radius: 14
            }
        }
    }

    readonly property bool gripShown: editLayer.item ? editLayer.item.gripShown : false
    readonly property bool gripHovered: editLayer.item ? editLayer.item.gripHovered : false
    readonly property alias editLayer: editLayer
    readonly property alias sizeChrome: sizeChrome

    Loader {
        id: editLayer
        z: 50
        opacity: 1 - BarLayout.gapDragT
        active: block.editMode || block.revealT > 0.001
        sourceComponent: BarBlockEditLayer {
            block: blockEditor.block
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !block.editMode && !block.leaving && block.panelKind === "" && layout.isPrimary
        visible: enabled
        acceptedButtons: Qt.RightButton
        onClicked: GlobalStates.openEdit("edges")
    }
}
