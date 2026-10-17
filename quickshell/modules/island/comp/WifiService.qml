import QtQuick
import Quickshell.Io

QtObject {
    id: svc

    property bool enabled: false
    property string ssid: ""
    property var networks: []
    property string busy: ""
    property string error: ""
    readonly property bool scanning: scanProc.running

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
    }

    function scan() {
        if (!scanProc.running)
            scanProc.running = true
    }

    function run(cmd) {
        if (actProc.running)
            return false
        actProc.command = cmd
        actProc.running = true
        return true
    }

    function setEnabled(on) {
        if (!run(["nmcli", "radio", "wifi", on ? "on" : "off"]))
            return
        enabled = on
        if (!on) {
            networks = []
            ssid = ""
        }
    }

    function connect(name, password, saved) {
        let cmd = ["nmcli", "device", "wifi", "connect", name]
        if (saved)
            cmd = ["nmcli", "connection", "up", "id", name]
        else if (password !== "")
            cmd = ["nmcli", "device", "wifi", "connect", name, "password", password]
        if (run(cmd))
            busy = name
    }

    function disconnect(name) {
        if (run(["nmcli", "connection", "down", "id", name]))
            busy = name
    }

    function forget(name) {
        run(["nmcli", "connection", "delete", "id", name])
    }

    function unesc(s) {
        return s.replace(/\\:/g, ":")
    }

    property Process statusProc: Process {
        command: ["sh", "-c", [
            'echo "radio=$(nmcli radio wifi)"',
            'nmcli -t -f IN-USE,SSID dev wifi list --rescan no | while IFS= read -r l; do case "$l" in "*:"*) echo "ssid=$(echo "$l" | cut -d: -f2-)";; esac; done'
        ].join("\n")]

        stdout: StdioCollector {
            onStreamFinished: {
                let name = ""
                for (const l of text.split("\n")) {
                    if (l.startsWith("radio="))
                        svc.enabled = l.slice(6).trim() === "enabled"
                    else if (l.startsWith("ssid="))
                        name = svc.unesc(l.slice(5).trim())
                }
                svc.ssid = name
            }
        }
    }

    property Process scanProc: Process {
        command: ["sh", "-c", [
            'nmcli -t -f NAME,TYPE connection show | while IFS= read -r l; do case "$l" in *:802-11-wireless) echo "saved=${l%:802-11-wireless}";; esac; done',
            'nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan yes | while IFS= read -r l; do echo "net=$l"; done'
        ].join("\n")]

        stdout: StdioCollector {
            onStreamFinished: {
                const saved = {}
                const nets = {}
                for (const l of text.split("\n")) {
                    if (l.startsWith("saved=")) {
                        saved[svc.unesc(l.slice(6).trim())] = true
                    } else if (l.startsWith("net=")) {
                        const p = l.slice(4).split(":")
                        if (p.length < 4)
                            continue
                        const name = svc.unesc(p.slice(3).join(":"))
                        if (name === "")
                            continue
                        const sig = Number(p[1]) || 0
                        const n = {
                            ssid: name,
                            signal: sig,
                            secure: p[2] !== "" && p[2] !== "--",
                            active: p[0] === "*",
                            saved: false
                        }
                        const prev = nets[name]
                        if (!prev || n.active || (!prev.active && sig > prev.signal))
                            nets[name] = n
                    }
                }
                const list = Object.keys(nets).map(k => {
                    nets[k].saved = saved[k] === true
                    return nets[k]
                })
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                svc.networks = list
                const cur = list.find(n => n.active)
                svc.ssid = cur ? cur.ssid : ""
            }
        }
    }

    property Process actProc: Process {
        stderr: StdioCollector {
            onStreamFinished: svc.error = text.trim()
        }

        onExited: {
            svc.busy = ""
            svc.refresh()
            if (svc.enabled)
                svc.scan()
        }
    }
}
