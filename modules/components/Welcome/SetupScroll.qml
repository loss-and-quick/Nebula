import QtQuick
import QtQuick.Controls
import qs.modules.components.custom

Flickable {
    id: scroller

    default property alias scrollData: holder.data
    readonly property real contentWidthAvail: scroller.width - 12
    readonly property real maxContentY: Math.max(0, contentHeight - height)

    contentHeight: holder.childrenRect.height
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 2500
    maximumFlickVelocity: 8000
    ScrollBar.vertical: CustomScrollBar {}

    function glideTo(dest) {
        const d = Math.max(0, Math.min(maxContentY, dest))
        if (Math.abs(d - contentY) < 0.5) return
        cancelFlick()
        glide.stop()
        glide.from = contentY
        glide.to = d
        glide.start()
    }

    NumberAnimation {
        id: glide
        target: scroller
        property: "contentY"
        duration: 380
        easing.type: Easing.OutCubic
    }

    Item {
        id: holder
        width: scroller.contentWidthAvail
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        z: -1

        onWheel: wheel => {
            wheel.accepted = false
            if (scroller.maxContentY <= 0) return

            const px = wheel.pixelDelta.y
            const ang = wheel.angleDelta.y
            if (px === 0 && ang === 0) return

            if (px !== 0) {
                const d = Math.max(0, Math.min(scroller.maxContentY, scroller.contentY - px))
                if (Math.abs(d - scroller.contentY) < 0.01) return
                glide.stop()
                scroller.cancelFlick()
                scroller.contentY = d
                wheel.accepted = true
                return
            }

            const base = glide.running ? glide.to : scroller.contentY
            const dest = base - (ang / 120) * 120
            if (Math.abs(Math.max(0, Math.min(scroller.maxContentY, dest)) - scroller.contentY) < 0.5) return

            scroller.glideTo(dest)
            wheel.accepted = true
        }
    }
}
