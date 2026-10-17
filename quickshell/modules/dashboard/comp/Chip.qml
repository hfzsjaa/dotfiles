import QtQuick
import QtQuick.Layouts

Rectangle {
    id: c

    required property var pal

    property string label: ""
    property string value: ""
    property real fraction: -1
    property color barColor: pal.accent

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 62
    radius: pal.cardRadius
    color: pal.tile

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 1

        Text {
            text: c.label
            color: c.pal.soft
            font.family: c.pal.textFont
            font.pixelSize: 10
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: c.value
            color: c.pal.fg
            font.family: c.pal.textFont
            font.pixelSize: 13
            font.bold: true
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            radius: 2
            visible: c.fraction >= 0
            color: c.pal.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, c.fraction))
                height: parent.height
                radius: parent.radius
                color: c.barColor

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
