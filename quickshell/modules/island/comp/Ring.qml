import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root

    required property var shell

    property real fraction: 0
    property string label: ""
    property string value: ""
    property color ringColor: shell.accentText
    property real shownFraction: fraction
    property real reveal: visible ? 1 : 0

    readonly property real size: 56
    readonly property real stroke: 7
    readonly property real arcR: (size - stroke) / 2

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 80

    Behavior on shownFraction {
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    Behavior on reveal {
        NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
    }

    Behavior on ringColor {
        ColorAnimation { duration: 240 }
    }

    Shape {
        x: (parent.width - root.size) / 2
        width: root.size
        height: root.size
        visible: root.visible
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.shell.trackColor
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.arcR
                radiusY: root.arcR
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.arcR
                radiusY: root.arcR
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(0.999, root.shownFraction * root.reveal))
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.value
            color: root.shell.barFg
            font.family: root.shell.textFont
            font.pixelSize: 11
            font.bold: true
            opacity: root.reveal
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        color: root.shell.softText
        font.family: root.shell.textFont
        font.pixelSize: 10
    }
}
