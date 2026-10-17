import QtQuick
import QtQuick.Layouts

Pressable {
    id: t

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 64
    radius: pal.cardRadius > 0 ? height / 2 : 0
    color: active ? pal.accent : pal.tile
    rippleColor: Qt.alpha(active ? pal.bg : pal.fg, 0.2)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 18
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: t.pal.cardRadius > 0 ? 20 : 0
            color: Qt.alpha(t.active ? t.pal.bg : t.pal.fg, t.active ? 0.16 : 0.1)

            Text {
                anchors.centerIn: parent
                text: t.icon
                color: t.active ? t.pal.bg : t.pal.fg
                font.family: t.pal.textFont
                font.pixelSize: 16
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: t.label
                color: t.active ? t.pal.bg : t.pal.fg
                font.family: t.pal.textFont
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                visible: t.sub !== ""
                elide: Text.ElideRight
                text: t.sub
                color: Qt.alpha(t.active ? t.pal.bg : t.pal.fg, 0.7)
                font.family: t.pal.textFont
                font.pixelSize: 10
            }
        }
    }
}
