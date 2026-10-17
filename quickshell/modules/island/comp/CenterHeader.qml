import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property var shell

    property string title: ""
    property bool checked: false
    property bool busy: false

    readonly property bool round: shell.innerRadius > 0

    signal back()
    signal toggled()
    signal action()

    spacing: 8

    onBusyChanged: {
        if (!busy)
            spin.rotation = 0
    }

    Pressable {
        shell: root.shell
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: root.round ? 18 : 0
        color: Qt.alpha(root.shell.barFg, 0.10)
        onClicked: root.back()

        Text {
            anchors.centerIn: parent
            text: "\uf104"
            color: root.shell.barFg
            font.family: root.shell.textFont
            font.pixelSize: 18
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.title
        color: root.shell.barFg
        font.family: root.shell.textFont
        font.pixelSize: 15
        font.bold: true
    }

    Pressable {
        shell: root.shell
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: root.round ? 18 : 0
        color: root.busy ? Qt.alpha(root.shell.accentText, 0.22) : Qt.alpha(root.shell.barFg, 0.10)
        onClicked: root.action()

        Text {
            id: spin
            anchors.centerIn: parent
            text: "\uf021"
            color: root.busy ? root.shell.accentText : root.shell.barFg
            font.family: root.shell.textFont
            font.pixelSize: 13

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            NumberAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }
    }

    Toggle {
        shell: root.shell
        checked: root.checked
        onToggled: root.toggled()
    }
}
