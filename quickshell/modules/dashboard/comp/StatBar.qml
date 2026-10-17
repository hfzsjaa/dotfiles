import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var shell
    property string label: ""
    property string value: ""
    property real fraction: -1
    property color barColor: shell.emph(shell.barMain, 1.25)

    Layout.fillWidth: true
    spacing: 4

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: root.label
            color: Qt.alpha(root.shell.barFg, 0.7)
            font.family: root.shell.textFont
            font.pixelSize: 12
            font.bold: true
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.value
            color: root.shell.barFg
            font.family: root.shell.textFont
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        visible: root.fraction >= 0
        Layout.fillWidth: true
        Layout.preferredHeight: 5
        radius: root.shell.cornerRadius > 0 ? 3 : 0
        color: Qt.alpha(root.shell.barFg, 0.15)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.fraction))
            height: parent.height
            radius: parent.radius
            color: root.barColor

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
}
