import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.dashboard
import qs.modules.dashboard.comp
import qs.modules.clipboard
import qs.modules.wallpaper
import qs.modules.overview
import qs.modules.common
import qs.modules.island
import qs.modules.island.comp
import qs.modules.powermenu
import qs.modules.lockscreen

ShellRoot {
    id: root

    property string barStyle: "notch"
    readonly property bool notch: barStyle === "notch"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    onBarStyleChanged: styleFile.setText(barStyle)

    onLayoutModeChanged: {
        if (layoutMode !== "float")
            overviewOpen = false
    }

    FileView {
        id: styleFile
        path: root.stateDir + "/bar-style"
        onLoaded: {
            const s = text().trim()
            if (s === "notch" || s === "dynamic")
                root.barStyle = s
        }
    }

    property int panelOpenMs: 520
    property int panelCloseMs: 380
    property real islandW: 0
    property real islandH: islandHeight
    property real islandR: cornerRadius
    property int cornerRadius: 14
    property int islandHeight: 36
    property int topMargin: notch ? 0 : 5
    property int notifWidth: 380
    property int morphMs: 240
    property int dismissMs: 600
    property int fastMs: 140
    property int midMs: 220
    property real uiScale: 1
    property var urgencyMs: [1000, 3000, 0]
    property bool lowPopup: false
    readonly property int leaveMs: Math.round(dismissMs * 0.65)
    property string textFont: "Hack Nerd Font"
    property string clockFont: "Ndot55"
    property var easeOut: [0.16, 1, 0.3, 1, 1, 1]
    property var easeSpring: [0.34, 1.56, 0.64, 1, 1, 1]
    readonly property color accentText: emph(barMain, 1.25)
    readonly property color softText: Qt.alpha(barFg, 0.55)
    readonly property color tileColor: Qt.alpha(barFg, 0.09)
    readonly property color trackColor: Qt.alpha(barFg, 0.16)
    readonly property int innerRadius: cornerRadius > 0 ? 18 : 0
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool clipboardOpen: false
    property bool wallpaperOpen: false
    property bool overviewOpen: false
    property bool powermenuOpen: false
    property bool ccOpen: false
    property bool notifOpen: false
    property bool lockLeaving: false
    property string layoutMode: "tile"
    CaptureService { id: captureService }
    property alias capture: captureService

    readonly property bool barHidden: launcherOpen || overviewOpen || wallpaperOpen || dashboardOpen || notifOpen || clipboardOpen || captureService.hideBar

    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    
    property bool osdShowing: false
    property bool osdArmed: false


    property color bg: "#000000"
    property color fg: "#ffffff"
    property color main: "#b48ead"
    property color accent: "#bf616a"

    property string wallpaperPath: ""
    property bool wallLight: false
    property real lightThreshold: 0.5

    readonly property bool light: wallLight

    property color barBg: root.bg
    property color barFg: root.fg
    property color barMain: wallLight ? Qt.darker(main, 1.5) : main

    Behavior on barBg {
        ColorAnimation {
            duration: 300
        }
    }
    Behavior on barFg {
        ColorAnimation {
            duration: 300
        }
    }
    Behavior on barMain {
        ColorAnimation {
            duration: 300
        }
    }

    Behavior on accent {
    ColorAnimation {
        duration: 300
    }
}

    function emph(c, k) {
        return wallLight ? Qt.darker(c, k) : Qt.lighter(c, k)
    }

    onWallpaperPathChanged: {
        if (!lumProc.running) {
            lumProc.src = wallpaperPath
            lumProc.running = true
        }
    }

    Process {
        id: lumProc
        property string src: ""
        command: ["sh", "-c", "m=$(command -v magick || command -v convert); \"$m\" \"$1[0]\" -gravity north -crop 50%x8%+0+0 +repage -resize '1x1!' -colorspace Gray -format '%[fx:mean]' info:", "sh", src]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text)
                if (!isNaN(v))
                    root.wallLight = v <= root.lightThreshold
            }
        }
        onExited: {
            if (src !== root.wallpaperPath) {
                src = root.wallpaperPath
                running = true
            }
        }
    }

    property int cpu: 0
    property int mem: 0
    property real lastIdle: 0
    property real lastTotal: 0
    property string netType: ""
    property string netName: ""
    property bool dnd: false
    property var notifs: []
    property var dropped: []

    readonly property var popups: notifs.filter(e => e.popup)
    readonly property var current: {
        let best = null
        for (let i = 0; i < popups.length; i++) {
            if (best === null || popups[i].urgency > best.urgency)
                best = popups[i]
        }
        return best
    }

    readonly property var sorted: notifs.slice().sort((a, b) => (b.urgency - a.urgency) || (b.time - a.time))

    readonly property var player: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
        }
        return null
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.osdArmed = true
    }

    Timer {
        id: osdHideTimer
        interval: 600
        onTriggered: root.osdShowing = false
    }

    function pokeOsd() {
        if (!root.osdArmed || root.ccOpen)
            return
        root.osdShowing = true
        osdHideTimer.restart()
    }

    Connections {
        target: root.audio
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            root.pokeOsd()
        }
        function onMutedChanged() {
            root.pokeOsd()
        }
    }

    function shouldPop(u) {
        if (u === NotificationUrgency.Critical)
            return true
        if (dnd)
            return false
        if (u === NotificationUrgency.Low)
            return lowPopup
        return true
    }

    function push(n, silent) {
        const existing = notifs.find(e => e.notif === n)
        if (existing) {
            if (!silent)
                existing.bump()
            return
        }
        n.tracked = true
        const entry = itemComp.createObject(root, {
            shell: root,
            notif: n,
            popup: !silent && shouldPop(n.urgency)
        })
        notifs = [entry, ...notifs]
        if (!silent && shouldPop(n.urgency))
            sound.playNotif()
    }

    function drop(entry) {
        dropped.push(entry)
        flush.restart()
    }

    function dismissCurrent() {
        if (current)
            current.dismiss(0, 0)
    }

    function clearAll() {
        const list = notifs.slice()
        const step = 35
        const last = Math.min(list.length - 1, 6) * step
        for (let i = 0; i < list.length; i++) {
            const d = Math.min(i, 6) * step
            list[i].dismiss(d, last - d)
        }
    }

    Sound {
        id: sound
    }

    Timer {
        id: flush
        interval: 0
        onTriggered: {
            const gone = root.dropped
            root.dropped = []
            root.notifs = root.notifs.filter(e => gone.indexOf(e) < 0)
            for (let i = 0; i < gone.length; i++)
                gone[i].destroy(500)
        }
    }

    Component {
        id: itemComp
        NotifItem {}
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => root.push(n, false)
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        const list = server.trackedNotifications.values
        for (let i = 0; i < list.length; i++)
            push(list[i], true)
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/hypr/layout-mode"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().trim()
            if (m === "tile" || m === "float")
                root.layoutMode = m
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text())
                root.bg = j.special.background
                root.fg = j.special.foreground
                root.main = j.colors.color13
                root.accent = j.colors.color5
                root.palette = j.colors
                root.wallpaperPath = j.wallpaper || ""
            } catch (e) {}
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.launcherOpen = !root.launcherOpen
        }
        function open(): void {
            root.launcherOpen = true
        }
        function close(): void {
            root.launcherOpen = false
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.dashboardOpen = !root.dashboardOpen
        }
        function open(): void {
            root.dashboardOpen = true
        }
        function close(): void {
            root.dashboardOpen = false
        }
    }

    IpcHandler {
    target: "notifications"

    function toggle(): void {
        root.notifOpen = !root.notifOpen
    }
    function open(): void {
        root.notifOpen = true
    }
    function close(): void {
        root.notifOpen = false
    }
    function toggleDnd(): void {
        root.dnd = !root.dnd
    }
    function clear(): void {
        root.clearAll()
    }
}


    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            root.clipboardOpen = !root.clipboardOpen
        }
        function open(): void {
            root.clipboardOpen = true
        }
        function close(): void {
            root.clipboardOpen = false
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.overviewOpen = root.layoutMode === "float" && !root.overviewOpen
        }
        function open(): void {
            root.overviewOpen = root.layoutMode === "float"
        }
        function close(): void {
            root.overviewOpen = false
        }
    }

    IpcHandler {
        target: "bar"

        function toggleStyle(): void {
            root.barStyle = root.notch ? "dynamic" : "notch"
        }
    }

        IpcHandler {
        target: "settingscenter"

        function toggle(): void {
            root.settingsCenterOpen = !root.settingsCenterOpen
        }
        function open(): void {
            root.settingsCenterOpen = true
        }
        function close(): void {
            root.settingsCenterOpen = false
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.wallpaperOpen = !root.wallpaperOpen
        }
        function open(): void {
            root.wallpaperOpen = true
        }
        function close(): void {
            root.wallpaperOpen = false
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            root.powermenuOpen = !root.powermenuOpen
        }
        function open(): void {
            root.powermenuOpen = true
        }
        function close(): void {
            root.powermenuOpen = false
        }
    }

    LockContext {
        id: lockContext
        onUnlocked: {
            if (root.lockLeaving)
                return
            root.lockLeaving = true
            leaveTimer.restart()
        }
    }

    Timer {
        id: leaveTimer
        interval: 1150
        onTriggered: {
            lock.locked = false
            root.lockLeaving = false
        }
    }

    WlSessionLock {
        id: lock
        locked: false

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext
                shell: root
            }
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void {
            leaveTimer.stop()
            root.lockLeaving = false
            lockContext.currentText = ""
            lock.locked = true
        }
        function unlock(): void {
            leaveTimer.stop()
            root.lockLeaving = false
            lock.locked = false
        }
    }

    Launcher {
        shell: root
        }
    Dashboard { shell: root }
    NotificationShade { shell: root }
    Wallpaper {
        shell: root
    }
    Clipboard {
        shell: root
    }
    Overview {
        shell: root
    }
    PowerMenu {
        shell: root
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + p[4]
            const total = p.reduce((a, b) => a + b, 0)
            const dt = total - root.lastTotal
            if (root.lastTotal > 0 && dt > 0)
                root.cpu = Math.round(100 * (1 - (idle - root.lastIdle) / dt))
            root.lastIdle = idle
            root.lastTotal = total
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const total = Number(t.match(/MemTotal:\s+(\d+)/)[1])
            const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1])
            root.mem = Math.round(100 * (1 - avail / total))
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload()
            memFile.reload()
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | grep ':connected:' | grep -v -e '^loopback' -e '^bridge' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (line === "") {
                    root.netType = ""
                    root.netName = ""
                    return
                }
                const p = line.split(":")
                root.netType = p[0]
                root.netName = p.slice(2).join(":")
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running)
                netProc.running = true
        }
    }

    property var cavaBars: []
    readonly property bool musicPlaying: player !== null

    Process {
        id: cavaProc
        running: root.musicPlaying
        command: ["sh", "-c",
            "mkdir -p \"$HOME/.cache/quickshell\"; cat > \"$HOME/.cache/quickshell/cava.conf\" <<'EOF'\n" +
            "[general]\nbars = 48\nframerate = 60\n\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\nEOF\n" +
            "exec cava -p \"$HOME/.cache/quickshell/cava.conf\""
        ]
        stdout: SplitParser {
            onRead: line => {
                const vals = line.split(";").filter(s => s.length > 0).map(Number)
                if (vals.length > 0)
                    root.cavaBars = vals
            }
        }
        onRunningChanged: {
            if (!running)
                root.cavaBars = []
        }
    }

    Variants {
        model: Quickshell.screens

        Island {
            shell: root
        }
    }
}
