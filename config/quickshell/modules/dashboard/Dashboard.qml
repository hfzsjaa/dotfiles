import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../notifications"

PanelWindow {
    id: win

    required property var shell

    property bool open: false
    property int fadeMs: 120
    property var targetScreen: Quickshell.screens[0]
    property int panelWidth: 820

    readonly property bool notch: shell.notch
    readonly property bool scrollBusy: scroll.moving || scroll.flicking

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
    property var cpuHist: new Array(30).fill(0)
    property var downHist: new Array(30).fill(0)
    property bool wifiOn: false
    property bool btOn: false
    property string wifiSSID: ""

    readonly property var connTiles: [
        { icon: "\uf1eb", label: "Wi-Fi", 
        check: "nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2}'; nmcli radio wifi | grep -q enabled && echo 1 || echo 0",
        on: "nmcli radio wifi on", off: "nmcli radio wifi off" },
        { icon: "\uf293", label: "Bluetooth", check: "bluetoothctl show | grep -q 'Powered: yes' && echo 1 || echo 0", on: "bluetoothctl power on", off: "bluetoothctl power off" }
    ]

    function setConnState(i, v) {
        if (i === 0)
            wifiOn = v
        else if (i === 1)
            btOn = v
    }

    readonly property int panelRadius: shell.cornerRadius > 0 ? 20 : 0
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color dim: Qt.alpha(shell.barFg, 0.7)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color trackColor: Qt.alpha(shell.barFg, 0.15)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.08)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.08)

    readonly property var player: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || panel.opacity > 0

    WlrLayershell.namespace: "island-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function greeting() {
        const h = clk.date.getHours()
        const name = Quickshell.env("USER")
        const g = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return name ? g + ", " + name : g
    }

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

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0
        const m = Math.floor(sec / 60)
        const s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function sample() {
        cpuHist = cpuHist.concat([shell.cpu]).slice(-30)
    }

    Connections {
        target: win.shell

        function onDashboardOpenChanged() {
            if (win.shell.dashboardOpen) {
                const m = Hyprland.focusedMonitor
                const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
                win.targetScreen = s || Quickshell.screens[0]
                win.shell.ccOpen = false
                win.shell.launcherOpen = false
                win.shell.clipboardOpen = false
                win.open = true
            } else {
                win.open = false
                win.lastRx = -1
            }
        }

        function onCcOpenChanged() {
            if (win.shell.ccOpen)
                win.shell.dashboardOpen = false
        }

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen)
                win.shell.dashboardOpen = false
        }

        function onClipboardOpenChanged() {
            if (win.shell.clipboardOpen)
                win.shell.dashboardOpen = false
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.open
        onActivated: win.shell.dashboardOpen = false
    }

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
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
                win.downHist = win.downHist.concat([win.netDown]).slice(-30)
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

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.dashboardOpen = false
    }

    Rectangle {
        id: panel

        readonly property int pad: 12

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: shell.topMargin
        width: Math.min(win.panelWidth, win.width - 80)
        height: Math.min(win.height - shell.topMargin - 24, scroll.contentHeight + pad * 2)

        topLeftRadius: win.notch ? 0 : win.panelRadius
        topRightRadius: win.notch ? 0 : win.panelRadius
        bottomLeftRadius: win.panelRadius
        bottomRightRadius: win.panelRadius

        color: shell.barBg
        border.width: win.notch ? 0 : 1
        border.color: win.borderColor
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.8
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation { duration: win.fadeMs }
        }

        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
        }

        MouseArea {
            anchors.fill: parent
        }

        Shape {
            id: earL
            visible: win.notch
            anchors.top: parent.top
            anchors.right: parent.left
            width: win.panelRadius
            height: width
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: shell.barBg
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
            visible: win.notch
            anchors.top: parent.top
            anchors.left: parent.right
            width: win.panelRadius
            height: width
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: shell.barBg
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

        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.margins: panel.pad
            contentWidth: width
            contentHeight: cols.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            RowLayout {
                id: cols
                width: scroll.width
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    DashCard {
                        shell: win.shell
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: win.greeting()
                                color: win.dim
                                font.family: shell.textFont
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Qt.formatDateTime(clk.date, "HH:mm")
                                color: win.accentText
                                font.family: shell.clockFont
                                font.pixelSize: 72
                                font.bold: true
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: Qt.formatDateTime(clk.date, "dddd, d MMMM yyyy")
                                color: win.dim
                                font.family: shell.textFont
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    DashCard {
                        shell: win.shell
                        title: win.player && win.player.identity ? win.player.identity : "Media"
                        icon: "\uf001"
                        Layout.fillWidth: true

                        Text {
                            visible: win.player === null
                            Layout.alignment: Qt.AlignHCenter
                            text: "Nothing playing"
                            color: win.soft
                            font.family: shell.textFont
                            font.pixelSize: 12
                        }

                        RowLayout {
                            visible: win.player !== null
                            Layout.fillWidth: true
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                Layout.alignment: Qt.AlignTop

                                Rectangle {
                                    anchors.fill: parent
                                    radius: shell.cornerRadius > 0 ? 8 : 0
                                    color: win.tileColor
                                    visible: art.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf001"
                                        color: win.soft
                                        font.family: shell.textFont
                                        font.pixelSize: 18
                                    }
                                }

                                Image {
                                    id: art
                                    anchors.fill: parent
                                    source: win.player && win.player.trackArtUrl ? win.player.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: win.player ? win.player.trackTitle : ""
                                    color: shell.barFg
                                    font.family: shell.textFont
                                    font.pixelSize: 13
                                    font.bold: true
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: win.player ? win.player.trackArtist : ""
                                    color: win.soft
                                    font.family: shell.textFont
                                    font.pixelSize: 11
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        RowLayout {
                            visible: win.player !== null
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: win.player ? win.fmtTime(win.player.position) : ""
                                color: win.soft
                                font.family: shell.textFont
                                font.pixelSize: 11
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 5
                                Layout.alignment: Qt.AlignVCenter
                                radius: shell.cornerRadius > 0 ? 3 : 0
                                color: win.trackColor

                                Rectangle {
                                    width: parent.width * (win.player && win.player.length > 0 ? Math.min(1, win.player.position / win.player.length) : 0)
                                    height: parent.height
                                    radius: parent.radius
                                    color: win.accentText
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.topMargin: -8
                                    anchors.bottomMargin: -8
                                    onClicked: mouse => {
                                        if (win.player && win.player.canSeek && win.player.length > 0)
                                            win.player.position = Math.max(0, Math.min(1, mouse.x / width)) * win.player.length
                                    }
                                }
                            }

                            Text {
                                text: win.player ? win.fmtTime(win.player.length) : ""
                                color: win.soft
                                font.family: shell.textFont
                                font.pixelSize: 11
                            }
                        }

                        RowLayout {
                            visible: win.player !== null
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 28

                            Text {
                                text: "\uf048"
                                color: shell.barFg
                                font.family: shell.textFont
                                font.pixelSize: 15

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    onClicked: {
                                        if (win.player)
                                            win.player.previous()
                                    }
                                }
                            }

                            Text {
                                text: win.player && win.player.isPlaying ? "\uf04c" : "\uf04b"
                                color: win.accentText
                                font.family: shell.textFont
                                font.pixelSize: 18

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    onClicked: {
                                        if (win.player)
                                            win.player.togglePlaying()
                                    }
                                }
                            }

                            Text {
                                text: "\uf051"
                                color: shell.barFg
                                font.family: shell.textFont
                                font.pixelSize: 15

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    onClicked: {
                                        if (win.player)
                                            win.player.next()
                                    }
                                }
                            }
                        }
                    }

                    DashCard {
                        shell: win.shell
                        title: "Notifications"
                        icon: "\uf0f3"
                        Layout.fillWidth: true

                        headerContent: [
                            Text {
                                text: "\uf1f6"
                                color: win.shell.dnd ? shell.accent : win.soft
                                font.family: shell.textFont
                                font.pixelSize: 12

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: win.shell.dnd = !win.shell.dnd
                                }
                            },
                            Text {
                                visible: win.shell.notifs.length > 0
                                text: "\uf1f8 Clear"
                                color: win.dim
                                font.family: shell.textFont
                                font.pixelSize: 12
                                font.bold: true

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: win.shell.clearAll()
                                }
                            }
                        ]

                        Text {
                            visible: win.shell.notifs.length === 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 6
                            text: "No notifications"
                            color: win.soft
                            font.family: shell.textFont
                            font.pixelSize: 12
                        }

                        ListView {
                            id: nlist
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(320, contentHeight)
                            visible: count > 0
                            clip: true
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            model: ScriptModel { values: win.shell.sorted }

                            delegate: Item {
                                id: row
                                required property var modelData
                                readonly property bool leaving: modelData ? modelData.leaving : false

                                width: nlist.width
                                height: card.implicitHeight

                                NotifCard {
                                    id: card
                                    width: parent.width
                                    shell: win.shell
                                    entry: row.modelData
                                    opacity: row.leaving ? 0 : 1

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: win.shell.leaveMs
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DashCard {
                        shell: win.shell
                        title: "Calendar"
                        icon: "\uf073"
                        Layout.fillWidth: true

                        MiniCalendar {
                            shell: win.shell
                            now: clk.date
                            enabled: !win.scrollBusy
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    DashCard {
                        shell: win.shell
                        title: "Connectivity"
                        icon: "\uf1eb"
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: win.connTiles

                                Rectangle {
                                    id: ctile
                                    required property int index
                                    required property var modelData

                                    readonly property bool active: index === 0 ? win.wifiOn : win.btOn

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 48
                                    radius: shell.cornerRadius > 0 ? 10 : 0
                                    color: active ? win.accentText : win.tileColor

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

                                    Connections {
                                        target: win
                                        function onOpenChanged() {
                                            if (win.open && !checkProc.running)
                                                checkProc.running = true
                                        }
                                    }

                                    Component.onCompleted: checkProc.running = true

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: ctile.modelData.icon
                                            color: ctile.active ? shell.barBg : shell.barFg
                                            font.family: shell.textFont
                                            font.pixelSize: 15
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: ctile.modelData.label
                                            color: ctile.active ? shell.barBg : shell.barFg
                                            font.family: shell.textFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: ctile.index === 0 && win.wifiOn && win.wifiSSID !== ""
                                            text: win.wifiSSID
                                            color: ctile.active ? Qt.alpha(shell.barBg, 0.8) : win.soft
                                            font.family: shell.textFont
                                            font.pixelSize: 7
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: ctile.width - 8
                                        }
                                    }

                                    Process {
                                        id: netmgrProc
                                        command: ["sh", "-c", "nm-connection-editor || nmtui || kcmshell6 kcm_networkmanagement || true"]
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => {
                                            if (ctile.index === 0 && mouse.button === Qt.RightButton) {
                                                win.shell.dashboardOpen = false
                                                netmgrProc.running = true
                                                return
                                            }
                                            if (actProc.running)
                                                return
                                            const next = !ctile.active
                                            win.setConnState(ctile.index, next)
                                            actProc.command = ["sh", "-c", next ? ctile.modelData.on : ctile.modelData.off]
                                            actProc.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DashCard {
                        shell: win.shell
                        title: "Audio"
                        icon: "\uf028"
                        Layout.fillWidth: true

                        Repeater {
                            model: ["sink", "source"]

                            RowLayout {
                                id: vrow
                                required property string modelData

                                readonly property bool isSink: modelData === "sink"
                                readonly property var node: isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
                                readonly property var audio: node ? node.audio : null
                                readonly property bool muted: audio ? audio.muted : false
                                readonly property real vol: audio ? audio.volume : 0

                                function setVol(v) {
                                    if (audio)
                                        audio.volume = Math.max(0, Math.min(1, v))
                                }

                                Layout.fillWidth: true
                                spacing: 10
                                visible: audio !== null
                                enabled: !win.scrollBusy

                                Text {
                                    Layout.preferredWidth: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: vrow.muted ? (vrow.isSink ? "\uf6a9" : "\uf131") : (vrow.isSink ? "\uf028" : "\uf130")
                                    color: vrow.muted ? shell.accent : shell.barFg
                                    font.family: shell.textFont
                                    font.pixelSize: 15

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: {
                                            if (vrow.audio)
                                                vrow.audio.muted = !vrow.audio.muted
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: shell.cornerRadius > 0 ? 3 : 0
                                    color: win.trackColor

                                    Rectangle {
                                        width: parent.width * Math.min(1, vrow.vol)
                                        height: parent.height
                                        radius: parent.radius
                                        color: vrow.muted ? shell.accent : win.accentText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: -8
                                        anchors.bottomMargin: -8
                                        onPressed: mouse => vrow.setVol(mouse.x / width)
                                        onPositionChanged: mouse => vrow.setVol(mouse.x / width)
                                        onWheel: wheel => vrow.setVol(vrow.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 38
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(vrow.vol * 100) + "%"
                                    color: shell.barFg
                                    font.family: shell.textFont
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }

                    DashCard {
                        shell: win.shell
                        title: "System"
                        icon: "\uf2db"
                        Layout.fillWidth: true

                        StatBar {
                            shell: win.shell
                            label: "CPU"
                            value: win.shell.cpu + "%"
                            fraction: win.shell.cpu / 100
                        }

                        Spark {
                            shell: win.shell
                            values: win.cpuHist
                            maxValue: 100
                        }

                        StatBar {
                            shell: win.shell
                            label: "Memory"
                            value: win.shell.mem + "%"
                            fraction: win.shell.mem / 100
                        }

                        StatBar {
                            visible: win.diskTotal > 0
                            shell: win.shell
                            label: "Disk /"
                            value: win.fmtBytes(win.diskUsed) + " / " + win.fmtBytes(win.diskTotal)
                            fraction: win.diskTotal > 0 ? win.diskUsed / win.diskTotal : 0
                        }

                        StatBar {
                            visible: win.battery >= 0
                            shell: win.shell
                            label: "Battery"
                            value: win.battery + "%" + (win.batteryState !== "" ? "  " + win.batteryState : "")
                            fraction: win.battery / 100
                            barColor: win.battery <= 20 && win.batteryState === "Discharging" ? shell.accent : win.accentText
                        }

                        StatBar {
                            visible: win.temp >= 0
                            shell: win.shell
                            label: "Temperature"
                            value: Math.round(win.temp) + "\u00b0C"
                        }
                    }

                    DashCard {
                        shell: win.shell
                        title: "Network"
                        icon: "\uf1eb"
                        Layout.fillWidth: true

                        StatBar {
                            shell: win.shell
                            label: win.shell.netType === "" ? "Offline" : (win.shell.netType === "wifi" ? "Wi-Fi" : "Ethernet")
                            value: win.shell.netName
                        }

                        StatBar {
                            shell: win.shell
                            label: "\uf063 Download"
                            value: win.fmtBytes(win.netDown) + "/s"
                        }

                        Spark {
                            shell: win.shell
                            values: win.downHist
                            maxValue: Math.max(51200, Math.max.apply(null, win.downHist))
                        }

                        StatBar {
                            shell: win.shell
                            label: "\uf062 Upload"
                            value: win.fmtBytes(win.netUp) + "/s"
                        }
                    }

                    PowerCard {
                        shell: win.shell
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
