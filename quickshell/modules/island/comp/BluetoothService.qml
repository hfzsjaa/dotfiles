import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool power: false
    property var devices: []
    property string busy: ""
    readonly property bool scanning: scanProc.running
    readonly property string connectedName: {
        for (const d of devices) {
            if (d.connected)
                return d.name
        }
        return ""
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
    }

    function scan() {
        if (power && !scanProc.running)
            scanProc.running = true
    }

    function run(cmd) {
        if (actProc.running)
            return false
        actProc.command = cmd
        actProc.running = true
        return true
    }

    function setPower(on) {
        if (!run(["bluetoothctl", "power", on ? "on" : "off"]))
            return
        power = on
        if (!on)
            devices = []
    }

    function connect(mac) {
        if (run(["bluetoothctl", "connect", mac]))
            busy = mac
    }

    function disconnect(mac) {
        if (run(["bluetoothctl", "disconnect", mac]))
            busy = mac
    }

    function pair(mac) {
        if (run(["sh", "-c", 'bluetoothctl pair "$1" && bluetoothctl trust "$1" && bluetoothctl connect "$1"', "sh", mac]))
            busy = mac
    }

    function remove(mac) {
        run(["bluetoothctl", "remove", mac])
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: scanProc.running
        repeat: true
        onTriggered: svc.refresh()
    }

    property Process statusProc: Process {
        command: ["sh", "-c", [
            'if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then echo "power=1"; else echo "power=0"; fi',
            'bluetoothctl devices 2>/dev/null | while read -r kw mac name; do',
            'i=$(bluetoothctl info "$mac" 2>/dev/null)',
            'c=0; echo "$i" | grep -q "Connected: yes" && c=1',
            'p=0; echo "$i" | grep -q "Paired: yes" && p=1',
            'b=$(echo "$i" | sed -n "s/.*Battery Percentage:.*(\\([0-9]*\\)).*/\\1/p")',
            'echo "dev=$mac|$c|$p|$b|$name"',
            'done'
        ].join("\n")]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const l of text.split("\n")) {
                    if (l.startsWith("power=")) {
                        svc.power = l.slice(6).trim() === "1"
                    } else if (l.startsWith("dev=")) {
                        const p = l.slice(4).split("|")
                        if (p.length < 5)
                            continue
                        const name = p.slice(4).join("|").trim()
                        if (name === "" || /^[0-9A-Fa-f]{2}(-[0-9A-Fa-f]{2}){5}$/.test(name))
                            continue
                        list.push({
                            mac: p[0],
                            connected: p[1] === "1",
                            paired: p[2] === "1",
                            battery: p[3] === "" ? -1 : Number(p[3]),
                            name: name
                        })
                    }
                }
                list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
                svc.devices = list
            }
        }
    }

    property Process scanProc: Process {
        command: ["bluetoothctl", "--timeout", "6", "scan", "on"]
        onExited: svc.refresh()
    }

    property Process actProc: Process {
        onExited: {
            svc.busy = ""
            svc.refresh()
        }
    }
}
