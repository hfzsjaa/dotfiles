import QtQuick
import Quickshell.Widgets

ClippingRectangle {
    id: p

    required property var pal

    signal clicked()
    signal secondary()

    property color rippleColor: Qt.alpha(pal.fg, 0.16)

    radius: pal.cardRadius
    scale: area.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
        }
    }

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    Rectangle {
        id: ripple

        property real cx: 0
        property real cy: 0
        property real r: 0

        x: cx - r
        y: cy - r
        width: r * 2
        height: r * 2
        radius: r
        opacity: 0
        color: p.rippleColor
    }

    ParallelAnimation {
        id: rippleAnim

        NumberAnimation {
            target: ripple
            property: "r"
            from: 0
            to: Math.hypot(p.width, p.height)
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }

        SequentialAnimation {
            NumberAnimation { target: ripple; property: "opacity"; to: 1; duration: 70 }
            PauseAnimation { duration: 120 }
            NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 260 }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: m => {
            ripple.cx = m.x
            ripple.cy = m.y
            rippleAnim.restart()
        }
        onClicked: m => {
            if (m.button === Qt.RightButton)
                p.secondary()
            else
                p.clicked()
        }
    }
}
