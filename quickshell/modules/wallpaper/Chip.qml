import QtQuick
import QtQuick.Layouts

Rectangle {
    id: chip

    required property var shell
    property string text: ""
    property bool active: false

    signal clicked()

    Layout.preferredHeight: 44
    implicitWidth: label.implicitWidth + 28
    radius: shell.cornerRadius > 0 ? 10 : 0
    color: active ? shell.emph(shell.barMain, 1.25) : Qt.alpha(shell.barFg, 0.08)

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.active ? chip.shell.barBg : chip.shell.barFg
        font.family: chip.shell.textFont
        font.pixelSize: 12
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: chip.clicked()
    }
}
