import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var shell

    property bool open: false
    property int fadeMs: 120
    property var targetScreen: Quickshell.screens[0]

    property int wsFilter: 0
    property string pendingExpr: ""

    readonly property bool notch: shell.notch
    readonly property int cardW: 200
    readonly property int cardH: 140
    readonly property int maxRows: 2
    readonly property int panelRadius: shell.cornerRadius > 0 ? 18 : 0
    readonly property int innerRadius: shell.cornerRadius > 0 ? 8 : 0
    readonly property int barH: 36
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color dim: Qt.alpha(shell.barFg, 0.7)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.08)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.08)

    readonly property string query: input.text.trim().toLowerCase()
    readonly property var entries: build(Hyprland.toplevels.values)
    readonly property var wsIds: {
        const seen = {}
        for (const e of entries)
            seen[e.ws] = true
        return Object.keys(seen).map(Number).sort((a, b) => a - b)
    }
    readonly property var results: {
        if (!open)
            return []
        const q = query
        return entries.filter(e => (wsFilter === 0 || e.ws === wsFilter)
            && (q === "" || e.title.toLowerCase().includes(q) || e.cls.toLowerCase().includes(q)))
    }
    readonly property int cols: Math.max(1, Math.floor(grid.width / cardW))

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

    WlrLayershell.namespace: "island-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function build(list) {
        const out = []
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const ipc = t.lastIpcObject || ({})
            if (ipc.mapped === false)
                continue
            const wl = t.wayland
            out.push({
                wayland: wl,
                address: t.address,
                ws: t.workspace ? t.workspace.id : (ipc.workspace ? ipc.workspace.id : 0),
                title: t.title || ipc.title || (wl ? wl.title : "") || "(untitled)",
                cls: ipc.class || (wl ? wl.appId : "") || "",
                active: !!wl && wl.activated
            })
        }
        out.sort((a, b) => (a.ws - b.ws) || a.title.localeCompare(b.title))
        return out
    }

    function wsLabel(id) {
        return id === 0 ? "All" : id > 0 ? String(id) : "S"
    }

    function iconFor(cls) {
        return cls === "" ? "" : Quickshell.iconPath(cls.toLowerCase(), true)
    }

    function move(d) {
        const n = results.length
        if (n === 0)
            return
        grid.currentIndex = Math.max(0, Math.min(n - 1, grid.currentIndex + d))
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    function selectActive() {
        const i = results.findIndex(e => e.active)
        grid.currentIndex = i >= 0 ? i : 0
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    function fullAddress(e) {
        if (!e || !e.address)
            return ""
        return e.address.startsWith("0x") ? e.address : "0x" + e.address
    }

    function run(expr) {
        pendingExpr = expr
        runTimer.restart()
    }

    function focusEntry(e) {
        if (!e)
            return
        shell.overviewOpen = false
        const addr = fullAddress(e)
        if (addr !== "") {
            run('hl.dsp.focus({ window = "address:' + addr + '" })')
        } else {
            if (e.ws > 0)
                run("hl.dsp.focus({ workspace = " + e.ws + " })")
            if (e.wayland)
                e.wayland.activate()
        }
    }

    function switchWorkspace(id) {
        shell.overviewOpen = false
        if (id > 0)
            run("hl.dsp.focus({ workspace = " + id + " })")
    }

    function closeEntry(e) {
        if (!e)
            return
        const addr = fullAddress(e)
        if (addr !== "")
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.close({ window = "address:' + addr + '" })'])
        else if (e.wayland)
            e.wayland.close()
        refreshTimer.restart()
    }

    Connections {
        target: win.shell

        function onOverviewOpenChanged() {
            if (win.shell.overviewOpen) {
                const m = Hyprland.focusedMonitor
                const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
                win.targetScreen = s || Quickshell.screens[0]
                win.shell.ccOpen = false
                win.shell.launcherOpen = false
                win.shell.dashboardOpen = false
                win.shell.clipboardOpen = false
                win.shell.wallpaperOpen = false
                input.text = ""
                win.wsFilter = 0
                Hyprland.refreshToplevels()
                win.open = true
                Qt.callLater(() => {
                    input.forceActiveFocus()
                    win.selectActive()
                })
            } else {
                win.open = false
            }
        }

        function onCcOpenChanged() {
            if (win.shell.ccOpen)
                win.shell.overviewOpen = false
        }

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen)
                win.shell.overviewOpen = false
        }

        function onDashboardOpenChanged() {
            if (win.shell.dashboardOpen)
                win.shell.overviewOpen = false
        }

        function onClipboardOpenChanged() {
            if (win.shell.clipboardOpen)
                win.shell.overviewOpen = false
        }

        function onWallpaperOpenChanged() {
            if (win.shell.wallpaperOpen)
                win.shell.overviewOpen = false
        }
    }

    Timer {
        id: runTimer
        interval: 80
        onTriggered: Quickshell.execDetached(["hyprctl", "dispatch", win.pendingExpr])
    }

    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: Hyprland.refreshToplevels()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("#000000", 0.5)
        opacity: win.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: win.fadeMs }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.overviewOpen = false
    }

    Rectangle {
        id: panel

        readonly property int padTop: 12
        readonly property int pad: 12

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: shell.topMargin
        width: Math.min(820, parent.width - 80)
        height: col.implicitHeight + padTop + pad

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

        Behavior on height {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
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

        ColumnLayout {
            id: col
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: panel.padTop
            anchors.leftMargin: panel.pad
            anchors.rightMargin: panel.pad
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: win.barH
                    radius: win.innerRadius
                    color: win.tileColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: "\uf2d2"
                            color: win.accentText
                            font.family: shell.textFont
                            font.pixelSize: 13
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text === ""
                                text: "Search windows"
                                color: win.soft
                                font.family: shell.textFont
                                font.pixelSize: 12
                            }

                            TextInput {
                                id: input
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                focus: true
                                color: shell.barFg
                                selectionColor: win.accentText
                                selectedTextColor: shell.barBg
                                font.family: shell.textFont
                                font.pixelSize: 12
                                font.bold: true

                                onTextChanged: {
                                    grid.currentIndex = 0
                                    grid.positionViewAtBeginning()
                                }

                                Keys.onPressed: event => {
                                    const ctrl = event.modifiers & Qt.ControlModifier
                                    const k = event.key

                                    if (k === Qt.Key_Escape) {
                                        win.shell.overviewOpen = false
                                    } else if (k === Qt.Key_Right || k === Qt.Key_Tab || (ctrl && k === Qt.Key_L)) {
                                        win.move(1)
                                    } else if (k === Qt.Key_Left || k === Qt.Key_Backtab || (ctrl && k === Qt.Key_H)) {
                                        win.move(-1)
                                    } else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_J)) {
                                        win.move(win.cols)
                                    } else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_K)) {
                                        win.move(-win.cols)
                                    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                        win.focusEntry(win.results[grid.currentIndex])
                                    } else if (k === Qt.Key_Delete || (ctrl && k === Qt.Key_W)) {
                                        win.closeEntry(win.results[grid.currentIndex])
                                    } else {
                                        return
                                    }
                                    event.accepted = true
                                }
                            }
                        }

                        Text {
                            text: win.results.length
                            color: win.soft
                            font.family: shell.textFont
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                Repeater {
                    model: [0].concat(win.wsIds)

                    Rectangle {
                        id: chip
                        required property int modelData
                        readonly property bool active: win.wsFilter === modelData

                        Layout.preferredHeight: win.barH
                        implicitWidth: Math.max(win.barH, label.implicitWidth + 22)
                        radius: win.innerRadius
                        color: active ? win.accentText : win.tileColor

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: win.wsLabel(chip.modelData)
                            color: chip.active ? shell.barBg : shell.barFg
                            font.family: shell.textFont
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    win.switchWorkspace(chip.modelData)
                                } else {
                                    win.wsFilter = chip.modelData
                                    grid.currentIndex = 0
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(win.cardH, Math.min(Math.ceil(win.results.length / win.cols), win.maxRows) * win.cardH)

                Text {
                    anchors.centerIn: parent
                    visible: win.results.length === 0
                    text: "No windows"
                    color: win.soft
                    font.family: shell.textFont
                    font.pixelSize: 11
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: count > 0
                    clip: true
                    cellWidth: Math.floor(width / win.cols)
                    cellHeight: win.cardH
                    currentIndex: 0
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel { values: win.results }

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index

                        readonly property bool selected: GridView.isCurrentItem

                        width: GridView.view.cellWidth
                        height: GridView.view.cellHeight

                        Rectangle {
                            id: frame
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: win.innerRadius
                            color: win.tileColor
                            border.width: cell.selected ? 2 : (cell.modelData.active ? 1 : 0)
                            border.color: cell.selected ? win.accentText : Qt.alpha(win.accentText, 0.5)

                            Item {
                                id: pv
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: parent.height - 12 - 24

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: !sc.hasContent
                                    spacing: 4

                                    Image {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        visible: status === Image.Ready
                                        source: win.iconFor(cell.modelData.cls)
                                        sourceSize: Qt.size(72, 72)
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "\uf2d0"
                                        visible: win.iconFor(cell.modelData.cls) === ""
                                        color: win.soft
                                        font.family: shell.textFont
                                        font.pixelSize: 22
                                    }
                                }

                                ScreencopyView {
                                    id: sc

                                    readonly property real ar: implicitHeight > 0 ? implicitWidth / implicitHeight : 1.6

                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height * ar)
                                    height: width / ar
                                    captureSource: cell.modelData.wayland
                                    live: win.open
                                    visible: hasContent
                                }
                            }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                height: 18
                                spacing: 6

                                Image {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    visible: status === Image.Ready
                                    source: win.iconFor(cell.modelData.cls)
                                    sourceSize: Qt.size(28, 28)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: cell.modelData.title
                                    color: cell.selected ? win.accentText : shell.barFg
                                    font.family: shell.textFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    text: win.wsLabel(cell.modelData.ws)
                                    color: win.soft
                                    font.family: shell.textFont
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onPositionChanged: grid.currentIndex = cell.index
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton)
                                    win.closeEntry(cell.modelData)
                                else
                                    win.focusEntry(cell.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}