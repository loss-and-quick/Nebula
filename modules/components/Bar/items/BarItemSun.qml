import qs.modules.components.Bar
import QtQuick
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.services
import qs.modules.components.custom

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: root.rise >= 0 && root.set > root.rise

    readonly property bool showLabel: BarLayout.opt(root.itemId, "showLabel") !== false

    function toMin(str) {
        const m = String(str ?? "").match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
        if (!m)
            return -1;
        let h = parseInt(m[1]);
        const ap = (m[3] ?? "").toUpperCase();
        if (ap === "PM" && h !== 12)
            h += 12;
        if (ap === "AM" && h === 12)
            h = 0;
        return h * 60 + parseInt(m[2]);
    }

    function span(mins) {
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return h > 0 ? h + "h " + String(m).padStart(2, "0") + "m" : m + "m";
    }

    readonly property int rise: root.toMin(ServiceWeather.astronomy?.sunrise)
    readonly property int set: root.toMin(ServiceWeather.astronomy?.sunset)
    readonly property int now: parseInt(ServiceClock.hour) * 60 + parseInt(ServiceClock.minute)
    readonly property bool day: root.now >= root.rise && root.now < root.set
    readonly property real t: {
        if (root.day)
            return (root.now - root.rise) / Math.max(1, root.set - root.rise);
        const night = 1440 - (root.set - root.rise);
        const since = root.now >= root.set ? root.now - root.set : root.now + 1440 - root.set;
        return since / Math.max(1, night);
    }
    readonly property int untilNext: root.day ? root.set - root.now : (root.now < root.rise ? root.rise - root.now : root.rise + 1440 - root.now)
    readonly property string label: (root.day ? "sunset in " : "sunrise in ") + root.span(root.untilNext)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 28

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Item {
            id: arc
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 22

            readonly property real baseY: 19
            readonly property real rx: 17
            readonly property real ry: 15
            readonly property real angle: Math.PI * (1 - root.t)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.day ? Colors.outlineVariant : Qt.alpha(Colors.outlineVariant, 0.6)
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [1.5, 2]
                    fillColor: "transparent"
                    startX: 20 - arc.rx
                    startY: arc.baseY
                    PathArc {
                        x: 20 + arc.rx
                        y: arc.baseY
                        radiusX: arc.rx
                        radiusY: arc.ry
                    }
                }

                ShapePath {
                    strokeColor: Colors.outlineVariant
                    strokeWidth: 1
                    fillColor: "transparent"
                    startX: 0
                    startY: arc.baseY
                    PathLine {
                        x: 40
                        y: arc.baseY
                    }
                }
            }

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                x: 20 + arc.rx * Math.cos(arc.angle) - width / 2
                y: root.day ? arc.baseY - arc.ry * Math.sin(arc.angle) - height / 2 : arc.baseY + 1
                color: root.day ? Colors.primary : "transparent"
                border.width: root.day ? 0 : 1.5
                border.color: Colors.outline
            }
        }

        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showLabel
            content: root.label
            size: 12
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
    }

    CustomToolTip {
        content: "Sunrise " + (ServiceWeather.astronomy?.sunrise ?? "") + " · Sunset " + (ServiceWeather.astronomy?.sunset ?? "")
        visible: hov.containsMouse
    }
}
