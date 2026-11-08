import qs.modules.components.Bar
import QtQuick
import Quickshell.Io
import qs.modules.utils
import qs.modules.components.custom

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: root.shownText !== ""

    readonly property string command: (BarLayout.opt(root.itemId, "command") ?? "").trim()
    readonly property string fixedText: BarLayout.opt(root.itemId, "text") ?? ""
    property string output: ""
    readonly property string shownText: root.command !== "" ? root.output : root.fixedText

    implicitWidth: label.implicitWidth
    implicitHeight: 24

    CustomText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        content: root.shownText
        size: BarLayout.opt(root.itemId, "size") ?? 13
        weight: BarLayout.opt(root.itemId, "bold") === false ? 500 : 700
    }

    Process {
        id: proc
        command: ["sh", "-c", root.command]
        stdout: StdioCollector {
            onStreamFinished: root.output = text.trim().split("\n")[0].slice(0, 80)
        }
    }

    Timer {
        interval: Math.max(1, BarLayout.opt(root.itemId, "interval") ?? 5) * 1000
        running: root.command !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running)
            proc.running = true
    }
}
