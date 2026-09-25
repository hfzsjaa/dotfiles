import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: win

    required property var shell
    required property var modelData

    property bool armed: false
    property bool showing: false

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color trackColor: Qt.alpha(shell.barFg, 0.15)

    screen: modelData
    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: panel.width
    implicitHeight: panel.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: showing
    mask: Region {}

    WlrLayershell.namespace: "island-osd"

    function show() {
        if (!armed || shell.ccOpen)
            return
        const m = Hyprland.focusedMonitor
        if (m && m.name !== modelData.name)
            return
        showing = true
        hideTimer.restart()
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: win.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: win.showing = false
    }

    Connections {
        target: win.audio
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            win.show()
        }

        function onMutedChanged() {
            win.show()
        }
    }

    Rectangle {
        id: panel
        width: 260
        height: 44
        radius: shell.cornerRadius > 0 ? height / 2 : 0
        color: shell.barBg
        border.width: 1
        border.color: Qt.alpha(shell.barFg, 0.08)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                text: win.muted ? "\uf6a9" : (win.volume < 0.34 ? "\uf026" : win.volume < 0.67 ? "\uf027" : "\uf028")
                color: win.muted ? shell.accent : shell.barFg
                font.family: shell.textFont
                font.pixelSize: 16
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                Layout.alignment: Qt.AlignVCenter
                radius: shell.cornerRadius > 0 ? 3 : 0
                color: win.trackColor

                Rectangle {
                    width: parent.width * Math.min(1, win.volume)
                    height: parent.height
                    radius: parent.radius
                    color: win.muted ? shell.accent : win.accentText
                }
            }

            Text {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: Math.round(win.volume * 100) + "%"
                color: shell.barFg
                font.family: shell.textFont
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
