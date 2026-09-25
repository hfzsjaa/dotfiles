import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var shell

    property bool open: false
    property var targetScreen: Quickshell.screens[0]

    property string dir: Quickshell.env("HOME") + "/wallpapers"
    property string transition: "random"
    property bool usePywal: true
    property string afterCommand: Quickshell.env("HOME") + "/.config/hypr/scripts/reload.sh"
    property bool reloadHyprland: true
    property var randomPool: ["grow", "outer", "wipe", "wave", "fade", "any"]

    property var items: []
    property string currentPath: ""
    property real wheelAcc: 0

    property var previewColors: []
    property bool previewLoading: false
    property string currentPreviewTarget: ""

    property int hoverIndex: -1
    readonly property int previewIndex: hoverIndex >= 0 && hoverIndex < results.length ? hoverIndex : carouselView.currentIndex
    readonly property string previewCacheHome: "/tmp/quickshell-wal-preview"

    readonly property var transitions: ["grow", "outer", "center", "wipe", "wave", "fade", "random", "none"]

    readonly property real panelWidth: 660
    readonly property real panelHeight: 235
    readonly property real baseWidth: 92
    readonly property real itemWidth: 158
    readonly property real itemHeight: 92
    readonly property real itemSpacing: 9
    readonly property int animMs: 300

    readonly property int innerRadius: shell.cornerRadius > 0 ? 11 : 0
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.07)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.09)

    readonly property string query: searchInput.text.trim().toLowerCase()
    readonly property var results: {
        if (!open)
            return []
        if (query === "")
            return items
        return items.filter(e => e.name.toLowerCase().includes(query))
    }

    readonly property var currentItem: results[carouselView.currentIndex]
    readonly property var labelItem: results[previewIndex]

    readonly property string label: {
        if (results.length === 0)
            return items.length === 0 ? "No wallpapers found in " + dir : "No matches"
        return labelItem ? labelItem.name : ""
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
    visible: open || island.progress > 0.001

    WlrLayershell.namespace: "island-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function parseList(raw) {
        const out = []
        for (const line of raw.split("\n")) {
            if (line === "")
                continue
            const base = line.slice(line.lastIndexOf("/") + 1)
            out.push({ path: line, name: base.replace(/\.[^.]+$/, "") })
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }

    function scrollTo(i, animate) {
        carouselView.highlightMoveDuration = animate ? win.animMs : 0
        carouselView.currentIndex = i
        if (!animate)
            carouselView.positionViewAtIndex(i, ListView.Center)
        previewTimer.restart()
    }

    function focusCurrent() {
        if (!open || results.length === 0)
            return
        const target = String(win.currentPath || "").trim()
        let i = results.findIndex(e => e.path === target)
        if (i < 0 && target !== "") {
            const base = target.slice(target.lastIndexOf("/") + 1)
            i = results.findIndex(e => e.path.slice(e.path.lastIndexOf("/") + 1) === base)
        }
        scrollTo(i >= 0 ? i : 0, false)
    }

    function move(d) {
        const n = results.length
        if (n === 0)
            return
        scrollTo(Math.max(0, Math.min(n - 1, carouselView.currentIndex + d)), true)
    }

    function cycleTransition() {
        transition = transitions[(transitions.indexOf(transition) + 1) % transitions.length]
    }

    function clearSearch() {
        searchInput.text = ""
        Qt.callLater(() => win.scrollTo(0, false))
    }

    function parseColors(raw) {
        return raw.split("\n").map(s => s.trim()).filter(s => s.startsWith("#"))
    }

    function requestPreview() {
        if (!open)
            return

        const item = results[previewIndex]
        const path = item ? item.path : ""

        if (!usePywal || path === "") {
            previewColors = []
            previewLoading = false
            currentPreviewTarget = ""
            return
        }

        if (path === currentPreviewTarget && previewColors.length > 0)
            return

        if (previewProc.running) {
            previewTimer.restart()
            return
        }

        currentPreviewTarget = path
        previewLoading = true
        previewProc.forPath = path
        previewProc.command = ["sh", "-c",
            'export HOME="$2"; mkdir -p "$HOME/.cache/wal"; '
            + 'wal -i "$1" -n -q >/dev/null 2>&1; '
            + 'cat "$HOME/.cache/wal/colors" 2>/dev/null',
            "sh", path, previewCacheHome]
        previewProc.running = true
    }

    function apply(item, closeAfter) {
        if (!item)
            return
        currentPath = item.path

        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"', "sh", item.path, Quickshell.env("HOME") + "/.cache/island-wallpaper/current"])

        let type = transition
        let extra = ""
        if (type === "random") {
            type = randomPool[Math.floor(Math.random() * randomPool.length)]
            if (type === "grow" || type === "outer")
                extra = " --transition-pos " + (0.1 + Math.random() * 0.8).toFixed(2)
                    + "," + (0.1 + Math.random() * 0.8).toFixed(2)
            else if (type === "wipe" || type === "wave")
                extra = " --transition-angle " + Math.floor(Math.random() * 360)
        }
        const steps = [{
            n: "awww",
            c: 'awww img "$1" --transition-type ' + type + extra
                + ' --transition-duration 1.2 --transition-fps 60'
        }]
        if (usePywal)
            steps.push({ n: "wal", c: 'wal -i "$1" -n -q' })
        if (afterCommand !== "")
            steps.push({ n: "hook", c: '"$3"' })
        if (reloadHyprland)
            steps.push({ n: "hyprctl reload", c: "hyprctl reload" })

        const body = steps.map(s => s.c + '; echo "' + s.n + ' exited with $?"').join("; ")
        const script = 'export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"; { ' + body
            + '; } > "$HOME/.cache/island-wallpaper.log" 2>&1'
        Quickshell.execDetached(["sh", "-c", script, "sh", item.path, transition, afterCommand])
        if (closeAfter)
            shell.wallpaperOpen = false
    }

    function random() {
        const n = results.length
        if (n === 0)
            return
        const i = Math.floor(Math.random() * n)
        scrollTo(i, true)
        apply(results[i], false)
    }

    Connections {
        target: win.shell

        function onWallpaperOpenChanged() {
            if (win.shell.wallpaperOpen) {
                const m = Hyprland.focusedMonitor
                const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
                win.targetScreen = s || Quickshell.screens[0]
                win.shell.ccOpen = false
                win.shell.launcherOpen = false
                win.shell.dashboardOpen = false
                win.shell.clipboardOpen = false
                searchInput.text = ""
                if (!findProc.running)
                    findProc.running = true
                win.open = true
                Qt.callLater(() => {
                    searchInput.forceActiveFocus()
                    win.focusCurrent()
                })
            } else {
                win.open = false
                win.hoverIndex = -1
            }
        }

        function onCcOpenChanged() {
            if (win.shell.ccOpen)
                win.shell.wallpaperOpen = false
        }

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen)
                win.shell.wallpaperOpen = false
        }

        function onDashboardOpenChanged() {
            if (win.shell.dashboardOpen)
                win.shell.wallpaperOpen = false
        }

        function onClipboardOpenChanged() {
            if (win.shell.clipboardOpen)
                win.shell.wallpaperOpen = false
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/wal"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const p = text().trim()
            if (p !== "")
                win.currentPath = p
        }
    }

    Process {
        id: findProc
        command: ["find", "-L", win.dir, "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", "-o", "-iname", "*.bmp", ")"]

        stdout: StdioCollector {
            onStreamFinished: {
                win.items = win.parseList(text)
                Qt.callLater(win.focusCurrent)
            }
        }
    }

    Timer {
        id: previewTimer
        interval: 300
        onTriggered: win.requestPreview()
    }

    Process {
        id: previewProc
        property string forPath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                win.previewLoading = false
                if (previewProc.forPath === win.currentPreviewTarget)
                    win.previewColors = win.parseColors(text)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.wallpaperOpen = false
    }

    Rectangle {
        id: island

        property real progress: win.open ? 1 : 0
        readonly property real p: Math.max(0, Math.min(1, progress))
        readonly property real r: win.shell.cornerRadius > 0 ? win.shell.cornerRadius + (24 - win.shell.cornerRadius) * p : 0

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: win.shell.topMargin
        width: win.baseWidth + (win.panelWidth - win.baseWidth) * progress
        height: win.shell.islandHeight + (win.panelHeight - win.shell.islandHeight) * progress

        topLeftRadius: win.shell.notch ? 0 : r
        topRightRadius: win.shell.notch ? 0 : r
        bottomLeftRadius: r
        bottomRightRadius: r

        color: win.shell.barBg
        border.width: win.shell.notch ? 0 : 1
        border.color: Qt.alpha(win.shell.barFg, 0.07)
        clip: true

        Behavior on progress {
            NumberAnimation {
                duration: win.open ? win.shell.morphMs + 120 : win.shell.leaveMs
                easing.type: win.open ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: 0.45
            }
        }

        Behavior on color {
            ColorAnimation { duration: 300 }
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: content
            anchors.top: parent.top
            anchors.topMargin: win.shell.islandHeight + 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: win.panelWidth - 24
            height: win.panelHeight - win.shell.islandHeight - 18
            opacity: Math.max(0, Math.min(1, (island.p - 0.45) / 0.4))
            enabled: win.open

            Item {
                id: header
                anchors.top: parent.top
                width: parent.width
                height: 30

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        id: searchBox
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        height: 28
                        radius: win.innerRadius
                        clip: true
                        color: win.tileColor
                        border.width: 1
                        border.color: searchInput.activeFocus ? win.accentText : win.borderColor

                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: win.accentText
                            opacity: searchInput.activeFocus ? 0.32 : 0

                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchInput.forceActiveFocus()
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf002"
                            color: searchInput.activeFocus ? win.accentText : win.soft
                            font.family: shell.textFont
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 28
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: "Search wallpapers"
                            color: Qt.alpha(shell.barFg, 0.35)
                            font.family: shell.textFont
                            font.pixelSize: 11
                        }

                        TextInput {
                            id: searchInput
                            anchors.left: parent.left
                            anchors.leftMargin: 28
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            focus: true
                            color: shell.barFg
                            selectionColor: win.accentText
                            selectedTextColor: shell.barBg
                            font.family: shell.textFont
                            font.pixelSize: 12

                            onTextChanged: Qt.callLater(() => win.scrollTo(0, false))

                            Keys.onPressed: event => {
                                const k = event.key

                                if (k === Qt.Key_Escape) {
                                    if (searchInput.text !== "")
                                        win.clearSearch()
                                    else
                                        win.shell.wallpaperOpen = false
                                } else if (k === Qt.Key_Right || k === Qt.Key_Tab) {
                                    win.move(1)
                                } else if (k === Qt.Key_Left || k === Qt.Key_Backtab) {
                                    win.move(-1)
                                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                    win.apply(win.results[carouselView.currentIndex], true)
                                } else {
                                    return
                                }
                                event.accepted = true
                            }
                        }
                    }

                    Chip {
                        shell: win.shell
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf0d0  " + win.transition
                        onClicked: win.cycleTransition()
                    }

                    Chip {
                        shell: win.shell
                        anchors.verticalCenter: parent.verticalCenter
                        text: "wal"
                        active: win.usePywal
                        onClicked: {
                            win.usePywal = !win.usePywal
                            previewTimer.restart()
                        }
                    }

                    Chip {
                        shell: win.shell
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf074"
                        onClicked: win.random()
                    }
                }
            }

            Item {
                id: palette
                anchors.top: header.bottom
                anchors.topMargin: 7
                width: parent.width
                height: 16
                opacity: win.usePywal ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 200 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        visible: win.previewLoading
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Generating palette\u2026"
                        color: win.soft
                        font.family: shell.textFont
                        font.pixelSize: 10
                    }

                    Text {
                        visible: !win.previewLoading && win.previewColors.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "No palette preview"
                        color: win.soft
                        font.family: shell.textFont
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: win.previewLoading ? [] : win.previewColors

                        delegate: Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            radius: 6.5
                            color: modelData
                            border.width: 1
                            border.color: win.borderColor
                            scale: 0
                            Component.onCompleted: scale = 1

                            Behavior on color { ColorAnimation { duration: win.animMs } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        }
                    }
                }
            }

            ListView {
                id: carouselView
                anchors.top: palette.bottom
                anchors.topMargin: 10
                width: parent.width
                height: win.itemHeight + 20
                clip: false

                orientation: ListView.Horizontal
                spacing: 0
                interactive: false
                cacheBuffer: 1200

                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - (win.itemWidth + win.itemSpacing)) / 2
                preferredHighlightEnd: (width + (win.itemWidth + win.itemSpacing)) / 2
                highlightMoveDuration: win.animMs
                highlightMoveVelocity: -1

                model: ScriptModel { values: win.results }

                header: Item { width: Math.max(0, (carouselView.width - win.itemWidth) / 2) }
                footer: Item { width: Math.max(0, (carouselView.width - win.itemWidth) / 2) }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                        win.wheelAcc += d
                        const steps = Math.trunc(win.wheelAcc / 120)
                        if (steps !== 0) {
                            win.wheelAcc -= steps * 120
                            win.move(-steps)
                        }
                    }
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index

                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property bool isHovered: win.hoverIndex === cell.index
                    readonly property bool isWallpaper: modelData.path === win.currentPath
                    readonly property real targetScale: isHovered ? 1.12 : (isCurrent ? 1.0 : 0.82)
                    property real pressScale: 1.0

                    width: win.itemWidth + win.itemSpacing
                    height: ListView.view.height
                    z: isHovered ? 30 : (isCurrent ? 10 : 1)

                    Rectangle {
                        id: glow
                        anchors.centerIn: frame
                        width: frame.width + 18
                        height: frame.height + 18
                        radius: win.innerRadius + 10
                        color: win.accentText
                        opacity: cell.isHovered ? 0.22 : 0

                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Behavior on width { NumberAnimation { duration: win.animMs; easing.type: Easing.OutExpo } }
                        Behavior on height { NumberAnimation { duration: win.animMs; easing.type: Easing.OutExpo } }
                    }

                    Rectangle {
                        id: frame
                        anchors.centerIn: parent
                        width: win.itemWidth * cell.targetScale
                        height: win.itemHeight * cell.targetScale
                        scale: cell.pressScale
                        radius: win.innerRadius
                        color: win.tileColor
                        clip: true
                        border.width: cell.isHovered ? 2 : (cell.isCurrent ? 1.5 : 1)
                        border.color: (cell.isHovered || cell.isCurrent) ? win.accentText : win.borderColor

                        Behavior on width { NumberAnimation { duration: win.animMs; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }
                        Behavior on height { NumberAnimation { duration: win.animMs; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        Behavior on border.color { ColorAnimation { duration: win.animMs } }
                        Behavior on border.width { NumberAnimation { duration: win.animMs } }

                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.modelData.path
                            sourceSize: Qt.size(win.itemWidth * 2, win.itemHeight * 2)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            opacity: cell.isHovered ? 1.0 : (cell.isCurrent ? 0.95 : 0.5)

                            Behavior on opacity { NumberAnimation { duration: win.animMs } }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 34
                            opacity: cell.isHovered ? 1 : 0

                            Behavior on opacity { NumberAnimation { duration: 180 } }

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.alpha(win.shell.bg, 0.85) }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 7
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: cell.modelData.name
                                color: "#ffffff"
                                font.family: shell.textFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Rectangle {
                            visible: cell.isWallpaper
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 16
                            height: 16
                            radius: 8
                            color: win.accentText
                            scale: cell.isWallpaper ? 1 : 0

                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00c"
                                color: shell.barBg
                                font.family: shell.textFont
                                font.pixelSize: 9
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onEntered: {
                            win.hoverIndex = cell.index
                            previewTimer.restart()
                        }

                        onExited: {
                            if (win.hoverIndex === cell.index)
                                win.hoverIndex = -1
                            previewTimer.restart()
                        }

                        onClicked: {
                            cell.pressScale = 0.94
                            pressReset.start()
                            win.scrollTo(cell.index, true)
                            win.apply(cell.modelData, false)
                        }
                    }

                    Timer {
                        id: pressReset
                        interval: 120
                        onTriggered: cell.pressScale = 1.0
                    }
                }
            }

            Text {
                anchors.top: carouselView.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: win.label
                color: win.results.length === 0 ? win.soft : win.accentText
                font.family: shell.textFont
                font.pixelSize: 11
                font.bold: true
            }
        }
    }

    Shape {
        id: earL
        visible: win.shell.notch
        anchors.top: island.top
        anchors.right: island.left
        width: island.r
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.shell.barBg
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
        visible: win.shell.notch
        anchors.top: island.top
        anchors.left: island.right
        width: island.r
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.shell.barBg
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
}
