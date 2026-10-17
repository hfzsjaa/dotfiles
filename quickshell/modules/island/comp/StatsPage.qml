import QtQuick
import QtQuick.Layouts
import Quickshell.Io

PageBox {
    id: page

    required property var shell

    property real diskUsed: 0
    property real diskTotal: 0
    property real temp: -1
    property int battery: -1
    property string batteryState: ""

    name: "stats"
    fromX: 30
    pageWidth: 340

    function refresh() {
        if (!infoProc.running)
            infoProc.running = true
    }

    onActiveChanged: {
        if (active)
            refresh()
    }

    Timer {
        interval: 5000
        running: page.active
        repeat: true
        onTriggered: page.refresh()
    }

    Process {
        id: infoProc
        command: ["sh", "-c", [
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
                    if (k === "disk") {
                        const p = v.split(" ")
                        page.diskUsed = Number(p[0]) || 0
                        page.diskTotal = Number(p[1]) || 0
                    } else if (k === "temp") {
                        page.temp = v === "" ? -1 : Number(v) / 1000
                    } else if (k === "bat") {
                        const p = v.split(" ")
                        page.battery = Number(p[0])
                        page.batteryState = p.slice(1).join(" ")
                    }
                }
            }
        }
    }


    Rectangle {
        Layout.fillWidth: true
        implicitHeight: ringRow.implicitHeight + 16
        radius: page.shell.innerRadius > 0 ? 22 : 0
        color: page.shell.tileColor

        RowLayout {
            id: ringRow
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Ring {
                shell: page.shell
                label: "CPU"
                value: page.shell.cpu + "%"
                fraction: page.shell.cpu / 100
                ringColor: page.shell.cpu > 85 ? page.shell.accent : page.shell.accentText
            }

            Ring {
                shell: page.shell
                label: "RAM"
                value: page.shell.mem + "%"
                fraction: page.shell.mem / 100
                ringColor: page.shell.mem > 90 ? page.shell.accent : page.shell.accentText
            }

            Ring {
                shell: page.shell
                label: "Disk"
                value: page.diskTotal > 0 ? Math.round(100 * page.diskUsed / page.diskTotal) + "%" : "-"
                fraction: page.diskTotal > 0 ? page.diskUsed / page.diskTotal : 0
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        InfoChip {
            shell: page.shell
            visible: page.temp >= 0
            text: "\uf2c9  " + Math.round(page.temp) + "\u00b0C"
        }

        InfoChip {
            shell: page.shell
            visible: page.battery >= 0
            text: "\uf240  " + page.battery + "%" + (page.batteryState === "Charging" ? "  \uf0e7" : "")
        }

        InfoChip {
            shell: page.shell
            text: page.shell.netType === "" ? "Offline" : "\uf1eb  " + (page.shell.netName !== "" ? page.shell.netName : page.shell.netType)
        }
    }
}