pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.components.custom

ColumnLayout {
    id: sizes

    property string kind: ""
    readonly property var spec: BarLayout.panelSpecs[sizes.kind] ?? null
    readonly property real screenH: sizes.Window.window ? sizes.Window.window.height : 1080

    spacing: 14

    Repeater {
        model: sizes.spec ? [
            { key: "w", label: "Width", min: sizes.spec.minW, max: sizes.spec.maxW, auto: false },
            { key: "h", label: "Height", min: sizes.spec.minH, auto: sizes.spec.autoH === true || sizes.spec.defH < 0,
              max: Math.max(sizes.spec.minH, Math.min(sizes.spec.maxH, sizes.screenH)) }
        ] : []

        delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property real value: row.modelData.key === "w" ? BarLayout.panelW(sizes.kind) : BarLayout.panelH(sizes.kind)
            readonly property int offset: row.modelData.auto ? 1 : 0
            readonly property bool isAuto: row.modelData.auto && row.value < 0
            readonly property int step: 10

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                CustomText { Layout.fillWidth: true; content: row.modelData.label; size: 14; weight: 500 }
                CustomText {
                    content: row.isAuto ? "Auto" : Math.round(row.value) + " px"
                    size: 13
                    customColor: Colors.surfaceVariantText
                }
            }

            M3Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                stepCount: Math.floor((row.modelData.max - row.modelData.min) / row.step) + 1 + row.offset
                currentStep: row.isAuto ? 0
                    : Math.max(row.offset, Math.min(stepCount - 1, Math.round((row.value - row.modelData.min) / row.step) + row.offset))
                valueText: row.modelData.auto && currentStep === 0 ? "Auto"
                    : String(row.modelData.min + (currentStep - row.offset) * row.step)
                onStepChanged: s => {
                    const v = row.modelData.auto && s === 0 ? -1 : row.modelData.min + (s - row.offset) * row.step
                    if (Math.abs(v - row.value) < row.step / 2 && (v < 0) === (row.value < 0))
                        return
                    if (row.modelData.key === "w")
                        BarLayout.setPanelSize(sizes.kind, v, BarLayout.panelH(sizes.kind))
                    else
                        BarLayout.setPanelSize(sizes.kind, BarLayout.panelW(sizes.kind), v)
                }
            }
        }
    }
}
