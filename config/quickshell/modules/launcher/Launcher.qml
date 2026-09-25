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
    property var usage: ({})
    property string terminal: "kitty"

    readonly property bool notch: shell.notch
    readonly property int rowHeight: 36
    readonly property int maxRows: 6
    readonly property int barH: 36
    readonly property int panelRadius: shell.cornerRadius > 0 ? 18 : 0
    readonly property int innerRadius: shell.cornerRadius > 0 ? 8 : 0
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color dim: Qt.alpha(shell.barFg, 0.7)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.08)
    readonly property color lineColor: Qt.alpha(shell.barFg, 0.1)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.08)

    readonly property string query: input.text.trim().toLowerCase()
    readonly property var apps: DesktopEntries.applications.values
    readonly property var results: open && !cmdMode ? search(query, apps, usage) : []

    readonly property bool cmdMode: input.text.startsWith(">")
    readonly property string cmdText: cmdMode ? input.text.slice(1).replace(/^\s+/, "") : ""

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

    WlrLayershell.namespace: "island-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function subseq(s, q) {
        let i = 0
        for (let j = 0; j < s.length && i < q.length; j++) {
            if (s[j] === q[i])
                i++
        }
        return i === q.length
    }

    function score(e, q) {
        const name = e.name.toLowerCase()
        let s = 0
        if (name === q)
            s = 100
        else if (name.startsWith(q))
            s = 80
        else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            s = 65
        else if (name.includes(q))
            s = 50
        else if (q.length > 1 && subseq(name, q))
            s = 25

        if (s === 0) {
            const extra = [e.genericName, e.comment, e.id, Array.from(e.keywords || []).join(" ")].join(" ").toLowerCase()
            if (extra.includes(q))
                s = 10
        }
        return s
    }

    function search(q, list, use) {
        const out = []
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            if (e.noDisplay)
                continue
            const bonus = Math.min(15, Math.log(1 + (use[e.id] || 0)) * 5)
            if (q === "") {
                out.push({ e: e, s: bonus })
            } else {
                const s = score(e, q)
                if (s > 0)
                    out.push({ e: e, s: s + bonus })
            }
        }
        out.sort((a, b) => (b.s - a.s) || a.e.name.localeCompare(b.e.name))
        return out.map(o => o.e)
    }

    function move(d) {
        const n = results.length
        if (n === 0)
            return
        list.currentIndex = (list.currentIndex + d + n) % n
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    function bump(id) {
        const u = Object.assign({}, usage)
        u[id] = (u[id] || 0) + 1
        usage = u
        store.setText(JSON.stringify(u))
    }

    function launch(e) {
        if (!e)
            return
        bump(e.id)
        shell.launcherOpen = false
        if (e.runInTerminal) {
            const args = e.command.filter(a => !a.startsWith("%"))
            Quickshell.execDetached([terminal, "-e"].concat(args))
        } else {
            e.execute()
        }
    }

    function runCommand(cmd) {
    if (!cmd)
        return
    shell.launcherOpen = false
    Quickshell.execDetached([terminal, "-e", "sh", "-c", cmd + "; exec $SHELL"])
    }

    function iconFor(name) {
        if (!name)
            return ""
        if (name.startsWith("/"))
            return "file://" + name
        if (name.startsWith("file:"))
            return name
        return Quickshell.iconPath(name, true)
    }

    Connections {
        target: win.shell

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen) {
                const m = Hyprland.focusedMonitor
                const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
                win.targetScreen = s || Quickshell.screens[0]
                win.shell.ccOpen = false
                input.text = ""
                list.currentIndex = 0
                win.open = true
                Qt.callLater(() => input.forceActiveFocus())
            } else {
                win.open = false
            }
        }
    }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.cache/island-launcher.json"
        onLoaded: {
            try {
                win.usage = JSON.parse(text())
            } catch (e) {}
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.launcherOpen = false
    }

    Rectangle {
        id: panel

        readonly property int padTop: 12
        readonly property int pad: 12

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: shell.topMargin
        width: 460
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
                Layout.preferredHeight: win.barH
                radius: win.innerRadius
                color: win.tileColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "\uf002"
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
                            text: "Search apps, or > to run a command"
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
                                win.shell.launcherOpen = false
                            } else if (win.cmdMode) {
                                if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                    win.runCommand(win.cmdText)
                                } else {
                                    return
                                }
                            } else if (k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && (k === Qt.Key_J || k === Qt.Key_N))) {
                                win.move(1)
                            } else if (k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && (k === Qt.Key_K || k === Qt.Key_P))) {
                                win.move(-1)
                            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                win.launch(win.results[list.currentIndex])
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

Text {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 2
    Layout.bottomMargin: 6
    visible: win.results.length === 0 && !win.cmdMode
    text: "No results"
    color: win.soft
    font.family: shell.textFont
    font.pixelSize: 11
}

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: win.rowHeight
    visible: win.cmdMode
    radius: win.innerRadius
    color: win.tileColor

    MouseArea {
        anchors.fill: parent
        onClicked: win.runCommand(win.cmdText)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: "\uf120"
            color: win.accentText
            font.family: shell.textFont
            font.pixelSize: 13
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: win.cmdText === "" ? "Type a command…" : "Run: " + win.cmdText
            color: win.cmdText === "" ? win.soft : shell.barFg
            font.family: shell.textFont
            font.pixelSize: 12
            font.bold: true
        }
    }
}

            ListView {
                id: list

                readonly property int rows: Math.min(count, win.maxRows)
                readonly property real fit: rows * win.rowHeight + Math.max(0, rows - 1) * spacing
                property real shownHeight: fit

                Layout.fillWidth: true
                Layout.preferredHeight: shownHeight
                visible: count > 0
                clip: true
                spacing: 3
                currentIndex: 0
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: win.results }

                Behavior on shownHeight {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index

                    readonly property bool selected: ListView.isCurrentItem
                    readonly property string iconSrc: win.iconFor(modelData.icon)

                    width: ListView.view.width
                    height: win.rowHeight
                    radius: win.innerRadius
                    color: selected ? win.accentText : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: list.currentIndex = row.index
                        onClicked: win.launch(row.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                visible: appIcon.status !== Image.Ready
                                text: "\uf009"
                                color: row.selected ? shell.barBg : win.soft
                                font.family: shell.textFont
                                font.pixelSize: 14
                            }

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: row.iconSrc
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: row.selected ? shell.barBg : shell.barFg
                            font.family: shell.textFont
                            font.pixelSize: 12
                            font.bold: true
                            textFormat: Text.PlainText
                        }

                        Text {
                            visible: row.modelData.runInTerminal
                            text: "\uf120"
                            color: row.selected ? Qt.alpha(shell.barBg, 0.7) : win.soft
                            font.family: shell.textFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}