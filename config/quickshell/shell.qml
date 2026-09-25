import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.dashboard
import qs.modules.clipboard
import qs.modules.wallpaper
import qs.modules.overview
import qs.modules.tray
import qs.modules.common
import qs.modules.powermenu
import qs.modules.lockscreen

ShellRoot {
    id: root

    property string barStyle: "notch"
    readonly property bool notch: barStyle === "notch"

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    onBarStyleChanged: styleFile.setText(barStyle)

    FileView {
        id: styleFile
        path: root.stateDir + "/bar-style"
        onLoaded: {
            const s = text().trim()
            if (s === "notch" || s === "dynamic")
                root.barStyle = s
        }
    }

    property int cornerRadius: 14
    property int islandHeight: 28
    property int topMargin: notch ? 0 : 5
    property int notifWidth: 380
    property int morphMs: 240
    property int dismissMs: 600
    property var urgencyMs: [1000, 3000, 0]
    property bool lowPopup: false
    readonly property int leaveMs: Math.round(dismissMs * 0.65)
    property string textFont: "DepartureMono Nerd Font"
    property string clockFont: "Ndot55"
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool clipboardOpen: false
    property bool wallpaperOpen: false
    property bool overviewOpen: false
    property bool powermenuOpen: false
    readonly property bool barHidden: launcherOpen || overviewOpen || wallpaperOpen || dashboardOpen || clipboardOpen
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    property bool osdShowing: false
    property bool osdArmed: false

    property alias recorder: rec

    Recorder {
        id: rec
    }

    property color bg: "#000000"
    property color fg: "#ffffff"
    property color main: "#b48ead"
    property color accent: "#bf616a"

    property string wallpaperPath: ""
    property bool wallLight: false
    property real lightThreshold: 0.5

        property color barBg: root.bg
        property color barFg: root.fg
        property color barMain: wallLight ? Qt.darker(main, 1.5) : main

    Behavior on barBg { ColorAnimation { duration: 300 } }
    Behavior on barFg { ColorAnimation { duration: 300 } }
    Behavior on barMain { ColorAnimation { duration: 300 } }

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
    property bool ccOpen: false
    property bool dnd: false
    property var notifs: []

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

        function onVolumeChanged() { root.pokeOsd() }
        function onMutedChanged() { root.pokeOsd() }
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

    property var dropped: []

    function drop(entry) {
        dropped.push(entry)
        flush.restart()
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

    Sound { id: sound }

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
                root.wallpaperPath = j.wallpaper || ""
            } catch (e) {}
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.launcherOpen = !root.launcherOpen }
        function open(): void { root.launcherOpen = true }
        function close(): void { root.launcherOpen = false }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void { root.dashboardOpen = !root.dashboardOpen }
        function open(): void { root.dashboardOpen = true }
        function close(): void { root.dashboardOpen = false }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void { root.clipboardOpen = !root.clipboardOpen }
        function open(): void { root.clipboardOpen = true }
        function close(): void { root.clipboardOpen = false }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void { root.overviewOpen = !root.overviewOpen }
        function open(): void { root.overviewOpen = true }
        function close(): void { root.overviewOpen = false }
    }

    IpcHandler {
        target: "bar"

        function toggleStyle(): void { root.barStyle = root.notch ? "dynamic" : "notch" }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void { root.wallpaperOpen = !root.wallpaperOpen }
        function open(): void { root.wallpaperOpen = true }
        function close(): void { root.wallpaperOpen = false }
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void { root.dnd = !root.dnd }
        function clear(): void { root.clearAll() }
    }

    IpcHandler {
    target: "powermenu"

    function toggle(): void { root.powermenuOpen = !root.powermenuOpen }
    function open(): void { root.powermenuOpen = true }
    function close(): void { root.powermenuOpen = false }
    }

    LockContext {
    id: lockContext

    onUnlocked: lock.locked = false
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
            lockContext.currentText = ""
            lock.locked = true
        }
        function unlock(): void { lock.locked = false }
    }

    Launcher {
        shell: root
    }

    Dashboard {
        shell: root
    }

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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            readonly property bool focusedHere: {
                const m = Hyprland.focusedMonitor
                return !m || m.name === modelData.name
            }
            readonly property bool notifying: !root.ccOpen && root.current !== null && focusedHere

            screen: modelData
            anchors.top: true
            margins.top: root.topMargin
            implicitWidth: 1400
            implicitHeight: 260
            exclusiveZone: root.islandHeight + root.topMargin
            color: "transparent"
            mask: Region { item: hit; Region { item: tray } }

            WlrLayershell.namespace: "island"

            Item {
                id: hit
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: root.barHidden ? 0 : (win.notifying ? root.notifWidth : content.implicitWidth + 20)
                height: root.barHidden ? 0 : (win.notifying ? Math.max(notifView.implicitHeight, root.islandHeight) : root.islandHeight)
            }

            Rectangle {
                id: island
                property bool expanded: false
                property var shown: null
                readonly property bool notifying: win.notifying
                readonly property bool osdMode: !notifying && root.osdShowing && win.focusedHere
                readonly property bool expandedMode: notifying || osdMode
                property real progress: expandedMode ? 1 : 0
                property real base: content.implicitWidth + 20
                property real tall: notifying
                    ? Math.max(notifView.implicitHeight, root.islandHeight)
                    : (osdMode ? Math.max(osdView.implicitHeight, root.islandHeight) : root.islandHeight)
                readonly property real expandedWidth: notifying ? root.notifWidth : (osdMode ? 260 : base)
                readonly property real p: Math.max(0, Math.min(1, progress))
                readonly property var live: root.current
                readonly property bool closing: !!shown && shown.closing
                readonly property bool critical: !!shown && notifying && shown.critical
                readonly property real r: root.cornerRadius > 0 ? root.cornerRadius + (24 - root.cornerRadius) * p : 0

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: base + (expandedWidth - base) * progress
                height: root.islandHeight + (tall - root.islandHeight) * progress

                topLeftRadius: root.notch ? 0 : r
                topRightRadius: root.notch ? 0 : r
                bottomLeftRadius: r
                bottomRightRadius: r

                color: root.barBg
                border.width: (critical || !root.notch) ? 1 : 0
                border.color: critical ? root.accent : Qt.alpha(root.barFg, 0.06)
                clip: true

                opacity: root.barHidden ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                onLiveChanged: {
                    if (live)
                        shown = live
                }

                onShownChanged: swap.restart()

                Behavior on progress {
                    NumberAnimation {
                        duration: island.notifying ? root.morphMs : (island.closing ? root.dismissMs : 180)
                        easing.type: island.notifying ? Easing.OutBack : (island.closing ? Easing.InOutCubic : Easing.OutCubic)
                        easing.overshoot: 0.45
                    }
                }

                Behavior on base {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Behavior on tall {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }

                Timer {
                    id: collapseTimer
                    interval: 300
                    onTriggered: island.expanded = false
                }

                NumberAnimation {
                    id: swap
                    target: notifView
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 140
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            collapseTimer.stop()
                            island.expanded = true
                        } else {
                            collapseTimer.restart()
                        }
                    }
                }

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 10
                    opacity: Math.max(0, 1 - island.p * 3)
                    enabled: !island.notifying

                    Row {
                        id: wsRow
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Repeater {
                            model: 4

                            Rectangle {
                                id: ws
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId

                                implicitWidth: active ? label.implicitWidth + 14 : 20
                                implicitHeight: 20
                                radius: implicitHeight / 2
                                color: active ? Qt.alpha(root.barMain, 0.26) : Qt.alpha(root.barFg, 0.07)

                                Behavior on implicitWidth {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutExpo }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: ws.wsId
                                    color: ws.active ? root.emph(root.barMain, 1.4) : Qt.alpha(root.barFg, 0.45)
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    font.bold: ws.active

                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: root.barFg
                                    opacity: wsArea.containsMouse && !ws.active ? 0.06 : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                MouseArea {
                                    id: wsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.wsId + " })")
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: root.emph(root.barMain, 1.25)
                        font.family: root.clockFont
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: Qt.alpha(root.barFg, 0.75)
                        font.family: root.textFont
                        font.pixelSize: 12
                        font.bold: true
                    }

                    RowLayout {
                        id: extras
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 10
                        opacity: island.expanded ? 1 : 0
                        visible: island.expanded || opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1
                            height: 12
                            color: Qt.alpha(root.barFg, 0.18)
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: 160
                            visible: root.player !== null
                            elide: Text.ElideRight
                            text: root.player ? "\uf001 " + root.player.trackTitle + (root.player.trackArtist ? " - " + root.player.trackArtist : "") : ""
                            color: Qt.alpha(root.barFg, 0.85)
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "\uebf3"
                            color: root.dashboardOpen ? root.emph(root.barMain, 1.25) : Qt.alpha(root.barFg, 0.5)
                            font.family: root.textFont
                            font.pixelSize: 12

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: root.dashboardOpen = !root.dashboardOpen
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: root.notch ? "\uf2d0" : "\uf2d2"
                            color: Qt.alpha(root.barFg, 0.5)
                            font.family: root.textFont
                            font.pixelSize: 12

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: root.barStyle = root.notch ? "dynamic" : "notch"
                            }
                        }

                        Text {
                            id: audioLabel
                            readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

                            Layout.alignment: Qt.AlignVCenter
                            text: !audio ? "" : (audio.muted ? "\uf6a9 muted" : (audio.volume < 0.34 ? "\uf026" : audio.volume < 0.67 ? "\uf027" : "\uf028") + " " + Math.round(audio.volume * 100) + "%")
                            color: audio && audio.muted ? root.accent : root.barFg
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton)
                                        Quickshell.execDetached(["pavucontrol"])
                                    else if (audioLabel.audio)
                                        audioLabel.audio.muted = !audioLabel.audio.muted
                                }
                                onWheel: wheel => {
                                    if (audioLabel.audio)
                                        audioLabel.audio.volume = Math.max(0, Math.min(1, audioLabel.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: 110
                            elide: Text.ElideRight
                            text: root.netType === "" ? "\uf127 offline" : (root.netType === "wifi" ? "\uf1eb " : "\uf796 ") + root.netName
                            color: root.netType === "" ? root.accent : root.barFg
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "\uf2db " + root.cpu + "%"
                            color: root.barFg
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "\uf538 " + root.mem + "%"
                            color: root.barFg
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }

                Item {
                    id: notifWrap
                    anchors.fill: parent
                    enabled: island.notifying
                    opacity: Math.max(0, Math.min(1, (island.p - 0.25) / 0.4))

                    NotifCard {
                        id: notifView
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: island.closing ? root.notifWidth * 0.3 * (1 - island.p) : 0
                        width: root.notifWidth
                        shell: root
                        entry: island.shown
                        popup: true
                        more: Math.max(0, root.popups.length - 1)
                    }
                }

                Item {
    id: osdWrap
    anchors.fill: parent
    enabled: island.osdMode
    visible: opacity > 0.001
    opacity: island.osdMode ? Math.max(0, Math.min(1, (island.p - 0.25) / 0.4)) : 0

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    RowLayout {
        id: osdView
        anchors.centerIn: parent
        width: parent.width - 28
        spacing: 10

        Text {
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
            text: root.audio && root.audio.muted ? "\uf6a9" : (root.audio && root.audio.volume < 0.34 ? "\uf026" : root.audio && root.audio.volume < 0.67 ? "\uf027" : "\uf028")
            color: root.audio && root.audio.muted ? root.accent : root.barFg
            font.family: root.textFont
            font.pixelSize: 15
        }

        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            Layout.alignment: Qt.AlignVCenter
                            radius: root.cornerRadius > 0 ? 3 : 0
                            color: Qt.alpha(root.barFg, 0.15)

                            Rectangle {
                                width: parent.width * (root.audio ? Math.min(1, root.audio.volume) : 0)
                                height: parent.height
                                radius: parent.radius
                                color: root.audio && root.audio.muted ? root.accent : root.emph(root.barMain, 1.25)

                                Behavior on width {
                                    NumberAnimation { duration: 120 }
                                }
                            }
                        }

                        Text {
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round((root.audio ? root.audio.volume : 0) * 100) + "%"
                            color: root.barFg
                            font.family: root.textFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }

            Shape {
                id: earL
                visible: root.notch
                anchors.top: parent.top
                anchors.right: island.left
                width: island.r
                height: width
                preferredRendererType: Shape.CurveRenderer

                opacity: root.barHidden ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                ShapePath {
                    fillColor: root.barBg
                    strokeWidth: 0
                    strokeColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: earL.width; y: 0 }
                    PathLine { x: earL.width; y: earL.height }
                    PathArc {
                        x: 0; y: 0
                        radiusX: earL.width; radiusY: earL.height
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Shape {
                id: earR
                visible: root.notch
                anchors.top: parent.top
                anchors.left: island.right
                width: island.r
                height: width
                preferredRendererType: Shape.CurveRenderer

                opacity: root.barHidden ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                ShapePath {
                    fillColor: root.barBg
                    strokeWidth: 0
                    strokeColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: earR.width; y: 0 }
                    PathArc {
                        x: 0; y: earR.height
                        radiusX: earR.width; radiusY: earR.height
                        direction: PathArc.Counterclockwise
                    }
                    PathLine { x: 0; y: 0 }
                }
            }

            TrayIsland {
                id: tray
                shell: root
                host: win
                anchors.top: parent.top
                anchors.right: island.left
                anchors.rightMargin: root.notch ? root.cornerRadius + 8 : 8
                enabled: !root.barHidden
                opacity: root.barHidden ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }
    }
}
