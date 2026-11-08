pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.settings

// Lightweight runtime instrumentation for panel lifecycle, layout geometry,
// and loader latency. Enable/disable via SettingsConfig.general.perfProfiling.
Singleton {
    id: root

    property bool enabled: SettingsConfig.general.perfProfiling ?? false
    readonly property string tag: "[PERF]"

    property int panelOpenCount: 0
    property int panelCloseCount: 0
    property int slotLoadCount: 0
    property int geometryRecomputeCount: 0
    property int hoverTransitionCount: 0
    property int bindingLoopWarnings: 0

    property real lastPanelOpenMs: 0
    property real lastSlotLoadMs: 0
    property real maxPanelOpenMs: 0
    property real maxSlotLoadMs: 0

    function markPanelOpen(kind) {
        if (!enabled)
            return;
        root.panelOpenCount++;
        root.lastPanelOpenMs = Date.now();
        console.log(root.tag, "panel open:", kind, "count=", root.panelOpenCount);
    }

    function markPanelClose(kind) {
        if (!enabled)
            return;
        root.panelCloseCount++;
        console.log(root.tag, "panel close:", kind, "count=", root.panelCloseCount);
    }

    function markSlotLoaded(kind, item) {
        if (!enabled)
            return;
        root.slotLoadCount++;
        root.lastSlotLoadMs = Date.now();
        console.log(root.tag, "slot loaded:", kind, "item=", item, "count=", root.slotLoadCount);
    }

    function markGeometry(x, w, h, state) {
        if (!enabled)
            return;
        root.geometryRecomputeCount++;
        console.log(root.tag, "geometry: x=", x, "w=", w, "h=", h, "state=", state);
    }

    function markHoverTransition(appId) {
        if (!enabled)
            return;
        root.hoverTransitionCount++;
        console.log(root.tag, "hover transition:", appId, "count=", root.hoverTransitionCount);
    }

    function markBindingLoopWarning(source) {
        if (!enabled)
            return;
        root.bindingLoopWarnings++;
        console.warn(root.tag, "binding loop:", source, "count=", root.bindingLoopWarnings);
    }

    function report() {
        console.log(root.tag, "summary: opens=", root.panelOpenCount, "closes=", root.panelCloseCount, "slotLoads=", root.slotLoadCount, "geomRecomputes=", root.geometryRecomputeCount, "hoverTransitions=", root.hoverTransitionCount, "bindingLoops=", root.bindingLoopWarnings);
    }

    Timer {
        interval: 30000
        running: root.enabled
        repeat: true
        onTriggered: root.report()
    }
}
