import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: root

    required property var shell

    property bool expanded: false
    property var capture: null

    readonly property bool round: shell.cornerRadius > 0
    readonly property bool showRec: capture !== null && capture.recording
    readonly property bool showDot: shell.notifs.length > 0 && !shell.dnd && !showRec
    readonly property bool showMusic: shell.player !== null
    readonly property string musicText: shell.player
        ? shell.player.trackTitle + (shell.player.trackArtist ? " - " + shell.player.trackArtist : "")
        : ""

    spacing: 10

    component Label: Text {
        Layout.alignment: Qt.AlignVCenter
        color: root.shell.barFg
        font.family: root.shell.textFont
        font.pixelSize: 11
        font.bold: true
    }

    component Chip: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: 18
        radius: root.round ? height / 2 : 0
        color: Qt.alpha(root.shell.barFg, 0.08)
    }

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 1
        Layout.preferredHeight: 12
        color: Qt.alpha(root.shell.barFg, 0.12)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        visible: root.showRec || root.showDot
        Layout.alignment: Qt.AlignVCenter
        spacing: 6

        Rectangle {
            visible: root.showDot
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 5
            Layout.preferredHeight: 5
            radius: root.round ? 3 : 0
            color: root.shell.accent
        }

        Rectangle {
            visible: root.showRec
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 7
            Layout.preferredHeight: 7
            radius: root.round ? 4 : 0
            color: root.shell.accent

            SequentialAnimation on opacity {
                running: root.showRec
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }

        Label {
            visible: root.showRec
            text: root.showRec ? root.capture.elapsedText : ""
            color: root.shell.accent
        }
    }

    Divider {
        visible: root.showRec || root.showDot
    }

    Chip {
        visible: root.showMusic
        implicitWidth: musicRow.implicitWidth + 16

        RowLayout {
            id: musicRow
            anchors.centerIn: parent
            spacing: 6

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                height: 12

                Repeater {
                    model: root.showMusic ? 5 : 0

                    Rectangle {
                        required property int index
                        readonly property real level: {
                            const b = root.shell.cavaBars
                            if (!b || b.length < 45)
                                return 0.15
                            let s = 0
                            for (let i = index * 9; i < index * 9 + 9; i++)
                                s += b[i]
                            return Math.min(1, s / 9 / 100 * 1.6)
                        }

                        width: 2.5
                        height: Math.max(3, 12 * level)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: root.round ? 1.5 : 0
                        color: root.shell.emph(root.shell.barMain, 1.25)

                        Behavior on height {
                            NumberAnimation { duration: 70 }
                        }
                    }
                }
            }

            Label {
                Layout.maximumWidth: 110
                elide: Text.ElideRight
                text: root.musicText
                color: Qt.alpha(root.shell.barFg, 0.85)
            }
        }
    }

    Chip {
        implicitWidth: dateText.implicitWidth + 16

        Text {
            id: dateText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd, d MMM")
            color: Qt.alpha(root.shell.barFg, 0.7)
            font.family: root.shell.textFont
            font.pixelSize: 11
            font.bold: true
        }
    }
}