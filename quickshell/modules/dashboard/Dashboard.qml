import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.dashboard.comp

ShadePanel {
    id: win

    tag: "island-dashboard"
    panelWidth: 520
    open: shell.dashboardOpen
    siblings: ["notifOpen"]
    onDismissed: shell.dashboardOpen = false
    onOpenChanged: {
        if (!open)
            lastRx = -1
    }

    property real uptime: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property real temp: -1
    property int battery: -1
    property string batteryState: ""
    property real netDown: 0
    property real netUp: 0
    property real lastRx: -1
    property real lastTx: 0
    property real lastNetTime: 0
    property bool wifiOn: false
    property bool btOn: false
    property string wifiSSID: ""

    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    readonly property var connTiles: [
        {
            icon: "\uf1eb",
            label: "Wi-Fi",
            check: "nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2}'; nmcli radio wifi | grep -q enabled && echo 1 || echo 0",
            on: "nmcli radio wifi on",
            off: "nmcli radio wifi off"
        },
        {
            icon: "\uf293",
            label: "Bluetooth",
            check: "bluetoothctl show | grep -q 'Powered: yes' && echo 1 || echo 0",
            on: "bluetoothctl power on",
            off: "bluetoothctl power off"
        }
    ]

    function fmtBytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024
            i++
        }
        return (i === 0 || b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i]
    }

    function fmtUptime(sec) {
        const d = Math.floor(sec / 86400)
        const h = Math.floor((sec % 86400) / 3600)
        const m = Math.floor((sec % 3600) / 60)
        return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
    }

    function setConnState(i, v) {
        if (i === 0)
            wifiOn = v
        else if (i === 1)
            btOn = v
    }

    component B: Block {
        reveal: win.reveal
    }

    component P: Pressable {
        pal: win.pal
    }

    component T: Tile {
        pal: win.pal
    }

    component S: Slide {
        pal: win.pal
    }

    component C: Chip {
        pal: win.pal
    }

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Timer {
        interval: 3000
        running: win.open
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!infoProc.running)
                infoProc.running = true
            netFile.reload()
        }
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            const now = Date.now()
            const lines = text().split("\n").slice(2)
            let rx = 0
            let tx = 0
            for (const line of lines) {
                const parts = line.split(":")
                if (parts.length < 2)
                    continue
                const n = parts[0].trim()
                if (n === "lo" || n.startsWith("veth") || n.startsWith("docker") || n.startsWith("br-"))
                    continue
                const f = parts[1].trim().split(/\s+/).map(Number)
                rx += f[0]
                tx += f[8]
            }
            if (win.lastRx >= 0 && now > win.lastNetTime) {
                const dt = (now - win.lastNetTime) / 1000
                win.netDown = Math.max(0, (rx - win.lastRx) / dt)
                win.netUp = Math.max(0, (tx - win.lastTx) / dt)
            }
            win.lastRx = rx
            win.lastTx = tx
            win.lastNetTime = now
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c", [
            'read up _ < /proc/uptime; echo "up=${up%.*}"',
            'set -- $(df -B1 --output=used,size / | tail -1); echo "disk=$1 $2"',
            't=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); echo "temp=$t"',
            'b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)',
            'if [ -n "$b" ]; then echo "bat=$(cat $b/capacity) $(cat $b/status)"; fi'
        ].join("\n")]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=")
                    if (i < 0)
                        continue
                    const k = l.slice(0, i)
                    const v = l.slice(i + 1).trim()
                    if (k === "up") {
                        win.uptime = Number(v) || 0
                    } else if (k === "disk") {
                        const p = v.split(" ")
                        win.diskUsed = Number(p[0]) || 0
                        win.diskTotal = Number(p[1]) || 0
                    } else if (k === "temp") {
                        win.temp = v === "" ? -1 : Number(v) / 1000
                    } else if (k === "bat") {
                        const p = v.split(" ")
                        win.battery = Number(p[0])
                        win.batteryState = p.slice(1).join(" ")
                    }
                }
            }
        }
    }

    B {
        order: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(clk.date, "HH:mm")
                    color: win.pal.accent
                    font.family: win.shell.clockFont
                    font.pixelSize: 40
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Qt.formatDateTime(clk.date, "ddd, d MMM") + (win.uptime > 0 ? "  \u00b7  up " + win.fmtUptime(win.uptime) : "")
                    color: win.pal.soft
                    font.family: win.pal.textFont
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            P {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: win.pal.cardRadius > 0 ? 22 : 0
                color: win.pal.tile
                onClicked: {
                    win.shell.dashboardOpen = false
                    win.shell.notifOpen = true
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf0f3"
                    color: win.pal.fg
                    font.family: win.pal.textFont
                    font.pixelSize: 16
                }

                Rectangle {
                    visible: win.shell.notifs.length > 0
                    width: 8
                    height: 8
                    radius: 4
                    x: parent.width - 16
                    y: 10
                    color: win.pal.alert
                }
            }
        }
    }

    B {
        order: 1

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: win.connTiles

                T {
                    id: ctile
                    required property int index
                    required property var modelData

                    icon: modelData.icon
                    label: modelData.label
                    sub: index === 0 ? (win.wifiOn ? (win.wifiSSID !== "" ? win.wifiSSID : "On") : "Off") : (win.btOn ? "On" : "Off")
                    active: index === 0 ? win.wifiOn : win.btOn

                    Process {
                        id: checkProc
                        command: ["sh", "-c", ctile.modelData.check]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const lines = text.trim().split("\n")
                                win.setConnState(ctile.index, lines[lines.length - 1] === "1")
                                if (ctile.index === 0)
                                    win.wifiSSID = lines.length > 1 ? lines.slice(0, -1).join(":").trim() : ""
                            }
                        }
                    }

                    Process {
                        id: actProc
                        onExited: checkProc.running = true
                    }

                    Process {
                        id: netmgrProc
                        command: ["sh", "-c", "nm-connection-editor || nmtui || kcmshell6 kcm_networkmanagement || true"]
                    }

                    Connections {
                        target: win
                        function onOpenChanged() {
                            if (win.open && !checkProc.running)
                                checkProc.running = true
                        }
                    }

                    Component.onCompleted: checkProc.running = true

                    onClicked: {
                        if (actProc.running)
                            return
                        const next = !active
                        win.setConnState(index, next)
                        actProc.command = ["sh", "-c", next ? modelData.on : modelData.off]
                        actProc.running = true
                    }

                    onSecondary: {
                        if (index === 0) {
                            win.shell.dashboardOpen = false
                            netmgrProc.running = true
                        }
                    }
                }
            }

            T {
                icon: "\uf1f6"
                label: "Silent"
                sub: win.shell.dnd ? "On" : "Off"
                active: win.shell.dnd
                onClicked: win.shell.dnd = !win.shell.dnd
            }

            T {
                icon: active ? "\uf466" : "\uf028"
                label: "Mute"
                sub: active ? "On" : "Off"
                active: win.sinkAudio ? win.sinkAudio.muted : false
                onClicked: {
                    if (win.sinkAudio)
                        win.sinkAudio.muted = !win.sinkAudio.muted
                }
            }
        }
    }

    B {
        order: 2

        Repeater {
            model: ["sink", "source"]

            S {
                id: sl
                required property string modelData

                readonly property bool isSink: modelData === "sink"
                readonly property var node: isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
                readonly property var audio: node ? node.audio : null

                visible: audio !== null
                icon: muted ? (isSink ? "\uf466" : "\uf131") : (isSink ? "\uf028" : "\uf130")
                value: audio ? audio.volume : 0
                muted: audio ? audio.muted : false
                onMoved: v => {
                    if (audio)
                        audio.volume = Math.max(0, Math.min(1, v))
                }
                onToggled: {
                    if (audio)
                        audio.muted = !audio.muted
                }
            }
        }
    }

    B {
        order: 3

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            C {
                label: "CPU"
                value: win.shell.cpu + "%"
                fraction: win.shell.cpu / 100
            }

            C {
                label: "Memory"
                value: win.shell.mem + "%"
                fraction: win.shell.mem / 100
            }

            C {
                visible: win.diskTotal > 0
                label: "Disk"
                value: win.fmtBytes(win.diskUsed)
                fraction: win.diskTotal > 0 ? win.diskUsed / win.diskTotal : -1
            }

            C {
                visible: win.battery >= 0
                label: win.batteryState !== "" ? "Battery  \u00b7  " + win.batteryState : "Battery"
                value: win.battery + "%"
                fraction: win.battery / 100
                barColor: win.battery <= 20 && win.batteryState === "Discharging" ? win.pal.alert : win.pal.accent
            }

            C {
                visible: win.temp >= 0
                label: "Temperature"
                value: Math.round(win.temp) + "\u00b0C"
            }

            C {
                label: "\uf063  Download"
                value: win.fmtBytes(win.netDown) + "/s"
            }

            C {
                label: "\uf062  Upload"
                value: win.fmtBytes(win.netUp) + "/s"
            }
        }
    }
}
