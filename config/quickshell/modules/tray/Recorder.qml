import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool recording: false
    property int elapsed: 0

    readonly property string formatted: format(elapsed)

    function format(sec) {
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        const s = sec % 60
        const mm = (m < 10 ? "0" : "") + m
        const ss = (s < 10 ? "0" : "") + s
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss
    }

    Process {
        id: probe
        command: ["sh", "-c", "pid=$(pgrep -xo wf-recorder) && ps -o etimes= -p \"$pid\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const sec = parseInt(text.trim())
                if (isNaN(sec)) {
                    root.recording = false
                    root.elapsed = 0
                } else {
                    root.recording = true
                    root.elapsed = sec
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!probe.running)
                probe.running = true
        }
    }
}