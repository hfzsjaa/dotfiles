import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: svc

    property bool recording: false
    property bool waiting: false
    property bool hideBar: false
    property bool primed: false
    property real startMs: 0
    property real now: Date.now()
    property string path: ""
    property string scriptDir: Quickshell.shellPath("modules/island/scripts")
    readonly property string elapsedText: {
        const s = Math.max(0, Math.floor((now - startMs) / 1000));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(s % 60);
    }
    property Timer shotDelay
    property Timer waitTimer
    property Timer pollTimer
    property Timer ticker
    property Process shotProc
    property Process recProc
    property Process checkProc

    signal notice(string icon, string text)

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function monitorName() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    }

    function workspaceId() {
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0;
    }

    function check() {
        if (!checkProc.running)
            checkProc.running = true;

    }

    function screenshot(mode) {
        if (shotProc.running || shotDelay.running)
            return ;

        hideBar = true;
        shotDelay.mode = mode;
        shotDelay.restart();
    }

    function record(mode) {
        if (recording || waiting)
            return ;

        waiting = true;
        waitTimer.restart();
        recProc.command = ["sh", scriptDir + "/record.sh", mode, monitorName()];
        recProc.running = true;
    }

    function stopRecording() {
        Quickshell.execDetached(["sh", "-c", 'read pid rest < "$HOME/.local/state/quickshell/recording" && kill -INT "$pid"']);
        check();
    }

    function toggleRecord(mode) {
        if (recording)
            stopRecording();
        else
            record(mode);
    }

    function apply(rec) {
        if (rec && !recording) {
            recording = true;
            waiting = false;
            if (primed)
                notice("\uf111", "Recording started");

        } else if (!rec && recording) {
            recording = false;
            notice("\uf00c", "Recording saved");
        }
        primed = true;
    }

    Component.onCompleted: check()

    recProc: Process {
        onExited: (code) => {
            if (code !== 0 && !svc.recording)
                svc.waiting = false;

        }
    }

    shotDelay: Timer {
        property string mode: "screen"

        interval: 280
        onTriggered: {
            shotProc.command = ["sh", svc.scriptDir + "/screenshot.sh", mode, svc.monitorName(), String(svc.workspaceId())];
            shotProc.running = true;
        }
    }

    waitTimer: Timer {
        interval: 90000
        onTriggered: svc.waiting = false
    }

    pollTimer: Timer {
        interval: 1500
        running: svc.recording || svc.waiting
        repeat: true
        onTriggered: svc.check()
    }

    ticker: Timer {
        interval: 1000
        running: svc.recording
        repeat: true
        onTriggered: svc.now = Date.now()
    }

    shotProc: Process {
        onExited: (code) => {
            svc.hideBar = false;
            if (code === 0)
                svc.notice("\uf030", "Screenshot saved");
            else if (code !== 1)
                svc.notice("\uf071", "Screenshot failed");
        }
    }

    checkProc: Process {
        command: ["sh", "-c", 'f="$HOME/.local/state/quickshell/recording"; if [ -f "$f" ]; then read pid ts path < "$f"; if kill -0 "$pid" 2>/dev/null; then echo "$ts $path"; else rm -f "$f"; fi; fi']

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t !== "") {
                    const i = t.indexOf(" ");
                    svc.startMs = Number(t.slice(0, i)) * 1000;
                    svc.path = t.slice(i + 1);
                    svc.now = Date.now();
                }
                svc.apply(t !== "");
            }
        }

    }

}
