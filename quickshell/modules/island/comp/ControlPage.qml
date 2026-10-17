import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.common

PageBox {
    id: page

    required property var shell
    required property var wifi
    required property var bt

    property bool nightOn: false
    property int nightTemp: 4000
    property bool caffeineOn: false

    readonly property var mic: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    signal openWifi()
    signal openBluetooth()

    name: "control"
    fromX: -30
    pageWidth: 340

    function applyNight() {
        Quickshell.execDetached(["sh", "-c", nightOn ? "pkill -x hyprsunset; exec hyprsunset -t " + nightTemp : "pkill -x hyprsunset"])
    }

    function toggleNight() {
        nightOn = !nightOn
        applyNight()
    }

    function toggleCaffeine() {
        caffeineOn = !caffeineOn
        Quickshell.execDetached(["sh", "-c", caffeineOn ? "pkill -x hypridle" : "setsid -f hypridle"])
    }

    onActiveChanged: {
        if (!active)
            return
        wifi.refresh()
        bt.refresh()
        if (!nightProc.running)
            nightProc.running = true
        if (!caffeineProc.running)
            caffeineProc.running = true
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }

    Process {
        id: nightProc
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 1 || echo 0"]

        stdout: StdioCollector {
            onStreamFinished: page.nightOn = text.trim() === "1"
        }
    }

    Process {
        id: caffeineProc
        command: ["sh", "-c", "pgrep -x hypridle >/dev/null && echo 0 || echo 1"]

        stdout: StdioCollector {
            onStreamFinished: page.caffeineOn = text.trim() === "1"
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        QuickTile {
            shell: page.shell
            icon: "\uf1eb"
            label: "Wi-Fi"
            sub: page.wifi.enabled ? (page.wifi.ssid !== "" ? page.wifi.ssid : "On") : "Off"
            active: page.wifi.enabled
            hasDetail: true
            onClicked: page.wifi.setEnabled(!page.wifi.enabled)
            onDetail: page.openWifi()
        }

        QuickTile {
            shell: page.shell
            icon: "\uf293"
            label: "Bluetooth"
            sub: page.bt.power ? (page.bt.connectedName !== "" ? page.bt.connectedName : "On") : "Off"
            active: page.bt.power
            hasDetail: true
            onClicked: page.bt.setPower(!page.bt.power)
            onDetail: page.openBluetooth()
        }

        QuickTile {
            shell: page.shell
            icon: "\uf186"
            label: "Night light"
            sub: page.nightOn ? page.nightTemp + "K" : "Off"
            active: page.nightOn
            onClicked: page.toggleNight()
        }

        QuickTile {
            shell: page.shell
            icon: "\uf130"
            label: "Mic"
            sub: page.mic ? (page.mic.muted ? "Muted" : "Live") : "N/A"
            active: page.mic ? !page.mic.muted : false
            onClicked: if (page.mic) page.mic.muted = !page.mic.muted
        }

        QuickTile {
            Layout.columnSpan: 2
            shell: page.shell
            icon: "\uf0f4"
            label: "Caffeine"
            sub: page.caffeineOn ? "Awake" : "Off"
            active: page.caffeineOn
            onClicked: page.toggleCaffeine()
        }
    }
}