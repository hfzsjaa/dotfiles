import QtQuick
import QtQuick.Layouts
import qs.modules.common

RowLayout {
    id: root

    required property var shell
    required property var audio

    readonly property bool round: shell.cornerRadius > 0
    readonly property bool muted: audio && audio.muted
    readonly property color tone: muted ? shell.accent : shell.emph(shell.barMain, 1.25)

    spacing: 8

    Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        radius: root.round ? 12 : 0
        color: Qt.alpha(root.muted ? root.shell.accent : root.shell.barFg, 0.14)

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        Text {
            anchors.centerIn: parent
            text: root.muted ? Icons.volumeMute : Icons.volume(root.audio)
            color: root.muted ? root.shell.accent : root.shell.barFg
            font.family: root.shell.textFont
            font.pixelSize: 12
            font.bold: true

            Behavior on color {
                ColorAnimation { duration: 160 }
            }
        }
    }

    Rectangle {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        Layout.alignment: Qt.AlignVCenter
        radius: root.round ? 3 : 0
        color: Qt.alpha(root.shell.barFg, 0.15)

        Rectangle {
            id: fill
            width: Math.max(parent.height, parent.width * (root.audio ? Math.min(1, root.audio.volume) : 0))
            height: parent.height
            radius: parent.radius
            color: root.tone

            Behavior on width {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 160 }
            }
        }

        Rectangle {
            width: 10
            height: 10
            radius: root.round ? 5 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
            color: root.tone

            Behavior on color {
                ColorAnimation { duration: 160 }
            }
        }
    }

    Text {
        Layout.preferredWidth: 28
        horizontalAlignment: Text.AlignRight
        text: Math.round((root.audio ? root.audio.volume : 0) * 100)
        color: root.shell.barFg
        font.family: root.shell.textFont
        font.pixelSize: 11
        font.bold: true
    }
}
