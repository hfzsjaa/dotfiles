import QtQuick
import QtQuick.Layouts
import Quickshell

DashCard {
    id: card

    property int pending: -1

    readonly property var actions: [
        { icon: "\uf023", label: "Lock", cmd: "sleep 0.3; pidof hyprlock || setsid hyprlock", confirm: false, danger: false },
        { icon: "\uf186", label: "Sleep", cmd: "sleep 0.3; systemctl suspend", confirm: false, danger: false },
        { icon: "\uf2f5", label: "Logout", cmd: "loginctl terminate-user $USER", confirm: true, danger: false },
        { icon: "\uf021", label: "Reboot", cmd: "systemctl reboot", confirm: true, danger: true },
        { icon: "\uf011", label: "Off", cmd: "systemctl poweroff", confirm: true, danger: true }
    ]

    title: "Power"
    icon: "\uf011"

    function trigger(i) {
        const a = actions[i]
        if (a.confirm && pending !== i) {
            pending = i
            resetTimer.restart()
            return
        }
        pending = -1
        resetTimer.stop()
        shell.dashboardOpen = false
        Quickshell.execDetached(["sh", "-c", a.cmd])
    }

    Timer {
        id: resetTimer
        interval: 3000
        onTriggered: card.pending = -1
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: card.actions

            Rectangle {
                id: btn
                required property var modelData
                required property int index
                readonly property bool confirming: card.pending === index

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 56
                radius: shell.cornerRadius > 0 ? 10 : 0
                color: confirming ? shell.accent : Qt.alpha(shell.barFg, 0.08)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: btn.modelData.icon
                        color: btn.confirming ? shell.barBg : (btn.modelData.danger ? shell.accent : shell.barFg)
                        font.family: shell.textFont
                        font.pixelSize: 16
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: btn.confirming ? "Sure?" : btn.modelData.label
                        color: btn.confirming ? shell.barBg : Qt.alpha(shell.barFg, 0.7)
                        font.family: shell.textFont
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.trigger(btn.index)
                }
            }
        }
    }
}
