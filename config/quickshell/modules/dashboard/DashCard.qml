import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property var shell
    property string title: ""
    property string icon: ""

    default property alias content: body.data
    property alias headerContent: hdr.data

    implicitHeight: col.implicitHeight + 28
    radius: shell.cornerRadius > 0 ? 12 : 0
    color: Qt.alpha(shell.barFg, 0.05)
    border.width: 1
    border.color: Qt.alpha(shell.barFg, 0.06)

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            visible: card.title !== ""
            spacing: 8

            Text {
                visible: card.icon !== ""
                text: card.icon
                color: shell.emph(shell.barMain, 1.25)
                font.family: shell.textFont
                font.pixelSize: 12
            }

            Text {
                text: card.title
                color: Qt.alpha(shell.barFg, 0.7)
                font.family: shell.textFont
                font.pixelSize: 12
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                id: hdr
                spacing: 10
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
        }
    }
}
