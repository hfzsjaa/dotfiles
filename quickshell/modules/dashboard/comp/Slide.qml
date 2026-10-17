import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

ClippingRectangle {
    id: s

    required property var pal

    signal moved(real v)
    signal toggled()

    property string icon: ""
    property real value: 0
    property bool muted: false

    Layout.fillWidth: true
    Layout.preferredHeight: 42
    radius: height / 2
    color: pal.track

    Rectangle {
        width: s.width * Math.min(1, s.value)
        height: s.height
        color: s.muted ? s.pal.alert : s.pal.accent

        Behavior on width {
            NumberAnimation { duration: 90 }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: m => s.moved(m.x / width)
        onPositionChanged: m => s.moved(m.x / width)
        onWheel: w => s.moved(s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    Text {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        text: s.icon
        color: s.value * s.width > 34 ? s.pal.bg : s.pal.fg
        font.family: s.pal.textFont
        font.pixelSize: 15

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            onClicked: s.toggled()
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(s.value * 100) + "%"
        color: s.value * s.width > s.width - 44 ? s.pal.bg : s.pal.fg
        font.family: s.pal.textFont
        font.pixelSize: 11
        font.bold: true
    }
}
