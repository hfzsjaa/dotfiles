import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var shell

    property bool open: false
    property int fadeMs: 120
    property var targetScreen: Quickshell.screens[0]

    property var items: []
    property bool confirmWipe: false
    property string currentId: ""
    property string previewText: ""
    property string previewImage: ""
    property int imgSlot: 0

    readonly property bool notch: shell.notch
    readonly property int rowHeight: 34
    readonly property int maxRows: 9
    readonly property int panelRadius: shell.cornerRadius > 0 ? 18 : 0
    readonly property int innerRadius: shell.cornerRadius > 0 ? 10 : 0
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color dim: Qt.alpha(shell.barFg, 0.7)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.08)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.08)

    readonly property string query: input.text.trim().toLowerCase()
    readonly property var results: {
        if (!open)
            return []
        const q = query
        return q === "" ? items : items.filter(e => e.text.toLowerCase().includes(q))
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

    WlrLayershell.namespace: "island-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onResultsChanged: previewTimer.restart()

    function parse(raw) {
        const out = []
        for (const line of raw.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab < 0)
                continue
            const id = line.slice(0, tab)
            if (!/^\d+$/.test(id))
                continue
            const body = line.slice(tab + 1)
            const m = body.match(/^\[\[ binary data (.+) \]\]$/)
            const isImage = !!m && /\d+x\d+/.test(m[1]) && /(png|jpe?g|bmp|gif|webp)/i.test(m[1])
            out.push({
                id: id,
                image: isImage,
                text: isImage ? "Image  " + m[1] : body.replace(/\s+/g, " ").trim()
            })
        }
        return out
    }

    function loadPreview() {
        const e = results[list.currentIndex]
        currentId = e ? e.id : ""
        if (!e) {
            previewText = ""
            previewImage = ""
            return
        }
        if (e.image) {
            previewText = ""
            if (imgProc.running)
                return
            imgSlot = (imgSlot + 1) % 2
            imgProc.forId = e.id
            imgProc.path = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/island-clip-" + imgSlot + ".img"
            imgProc.command = ["sh", "-c", "cliphist decode " + e.id + " > '" + imgProc.path + "'"]
            imgProc.running = true
        } else {
            previewImage = ""
            if (textProc.running)
                return
            textProc.forId = e.id
            textProc.command = ["cliphist", "decode", e.id]
            textProc.running = true
        }
    }

    function move(d) {
        const n = results.length
        if (n === 0)
            return
        list.currentIndex = (list.currentIndex + d + n) % n
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    function copy(e) {
        if (!e)
            return
        shell.clipboardOpen = false
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + e.id + " | wl-copy"])
    }

    function remove(e) {
        if (!e)
            return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' " + e.id + " | cliphist delete"])
        items = items.filter(x => x.id !== e.id)
        list.currentIndex = Math.max(0, Math.min(list.currentIndex, results.length - 1))
    }

    function wipe() {
        if (!confirmWipe) {
            confirmWipe = true
            return
        }
        Quickshell.execDetached(["cliphist", "wipe"])
        items = []
        confirmWipe = false
    }

    Connections {
        target: win.shell

        function onClipboardOpenChanged() {
            if (win.shell.clipboardOpen) {
                const m = Hyprland.focusedMonitor
                const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
                win.targetScreen = s || Quickshell.screens[0]
                win.shell.ccOpen = false
                win.shell.launcherOpen = false
                win.shell.dashboardOpen = false
                input.text = ""
                win.confirmWipe = false
                list.currentIndex = 0
                if (!listProc.running)
                    listProc.running = true
                win.open = true
                Qt.callLater(() => input.forceActiveFocus())
            } else {
                win.open = false
            }
        }

        function onCcOpenChanged() {
            if (win.shell.ccOpen)
                win.shell.clipboardOpen = false
        }

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen)
                win.shell.clipboardOpen = false
        }

        function onDashboardOpenChanged() {
            if (win.shell.dashboardOpen)
                win.shell.clipboardOpen = false
        }
    }

    Timer {
        id: previewTimer
        interval: 90
        onTriggered: win.loadPreview()
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: win.items = win.parse(text)
        }
    }

    Process {
        id: textProc
        property string forId: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (textProc.forId === win.currentId)
                    win.previewText = text.length > 4000 ? text.slice(0, 4000) + "..." : text
            }
        }

        onExited: {
            if (forId !== win.currentId)
                win.loadPreview()
        }
    }

    Process {
        id: imgProc
        property string forId: ""
        property string path: ""

        onExited: exitCode => {
            if (forId !== win.currentId)
                win.loadPreview()
            else if (exitCode === 0)
                win.previewImage = "file://" + path
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.clipboardOpen = false
    }

    Rectangle {
        id: panel

        readonly property int padTop: 10
        readonly property int pad: 10

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: shell.topMargin
        width: Math.min(700, win.width - 80)
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: win.innerRadius
                color: win.tileColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "\uf0ea"
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
                            text: "Search clipboard history"
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
                                list.currentIndex = 0
                                list.positionViewAtBeginning()
                            }

                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier
                                const k = event.key

                                if (k === Qt.Key_Escape) {
                                    win.shell.clipboardOpen = false
                                } else if (k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && (k === Qt.Key_J || k === Qt.Key_N))) {
                                    win.move(1)
                                } else if (k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && (k === Qt.Key_K || k === Qt.Key_P))) {
                                    win.move(-1)
                                } else if (k === Qt.Key_PageDown) {
                                    win.move(win.maxRows - 1)
                                } else if (k === Qt.Key_PageUp) {
                                    win.move(-(win.maxRows - 1))
                                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                    win.copy(win.results[list.currentIndex])
                                } else if (k === Qt.Key_Delete || (ctrl && k === Qt.Key_D)) {
                                    win.remove(win.results[list.currentIndex])
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

                    Text {
                        visible: win.items.length > 0
                        text: win.confirmWipe ? "Sure?" : "\uf1f8"
                        color: win.confirmWipe ? shell.accent : win.soft
                        font.family: shell.textFont
                        font.pixelSize: 12
                        font.bold: win.confirmWipe

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: win.wipe()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: win.maxRows * win.rowHeight + (win.maxRows - 1) * list.spacing

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: win.results.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: win.items.length === 0
                            ? "No clipboard history.\nIs 'wl-paste --watch cliphist store' running?"
                            : "No results"
                        color: win.soft
                        font.family: shell.textFont
                        font.pixelSize: 11
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        visible: count > 0
                        clip: true
                        spacing: 3
                        currentIndex: 0
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds
                        model: ScriptModel { values: win.results }

                        onCurrentIndexChanged: previewTimer.restart()

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index

                            readonly property bool selected: ListView.isCurrentItem

                            width: ListView.view.width
                            height: win.rowHeight
                            radius: win.innerRadius
                            color: selected ? win.accentText : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: list.currentIndex = row.index
                                onClicked: win.copy(row.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 9

                                Text {
                                    text: row.modelData.image ? "\uf03e" : "\uf0c5"
                                    color: row.selected ? shell.barBg : win.soft
                                    font.family: shell.textFont
                                    font.pixelSize: 12
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: row.modelData.text
                                    color: row.selected ? shell.barBg : shell.barFg
                                    font.family: shell.textFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: win.innerRadius
                    color: win.tileColor
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: win.currentId === ""
                        text: "Nothing selected"
                        color: win.soft
                        font.family: shell.textFont
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: win.previewImage === ""
                        text: win.previewText
                        color: shell.barFg
                        font.family: shell.textFont
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        clip: true
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: win.previewImage !== ""
                        source: win.previewImage
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        asynchronous: true
                    }
                }
            }
        }
    }
}
