import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var shell

    property string text: ""

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 28
    radius: shell.cornerRadius > 0 ? height / 2 : 0
    color: Qt.alpha(shell.barFg, 0.12)

    Text {
        anchors.centerIn: parent
        width: parent.width - 16
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.text
        color: root.shell.barFg
        font.family: root.shell.textFont
        font.pixelSize: 11
        font.bold: true
    }
}