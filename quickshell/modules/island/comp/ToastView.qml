import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var shell

    property string icon: ""
    property string text: ""
    readonly property bool alert: icon === "\uf111" || icon === "\uf071"
    readonly property color tone: alert ? shell.accent : shell.accentText

    spacing: 8

    onTextChanged: pop.restart()

    NumberAnimation {
        id: pop
        target: badge
        property: "scale"
        from: 0.5
        to: 1
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 2.4
    }

    Rectangle {
        id: badge
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        radius: root.shell.cornerRadius > 0 ? 12 : 0
        color: Qt.alpha(root.tone, 0.18)

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.tone
            font.family: root.shell.textFont
            font.pixelSize: 12

            Behavior on color {
                ColorAnimation { duration: 160 }
            }
        }
    }

    Text {
        Layout.maximumWidth: 220
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideRight
        text: root.text
        color: root.shell.barFg
        font.family: root.shell.textFont
        font.pixelSize: 11
        font.bold: true
    }
}
