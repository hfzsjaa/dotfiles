import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win

    required property var shell

    property bool open: false
    property var targetScreen: Quickshell.screens[0]

    property string lockCommand: "qs ipc call lockscreen lock"
    property string suspendCommand: "systemctl suspend"
    property string logoutCommand: "hyprctl dispatch exit"
    property string rebootCommand: "systemctl reboot"
    property string shutdownCommand: "systemctl poweroff"

    property int confirmMs: 2500
    property string armedAction: ""
    property int selected: -1

    property int openMs: shell.panelOpenMs || 420
    property int closeMs: shell.panelCloseMs || 320
    property real reveal: open ? 1 : 0

    property real islandW: 180
    property real islandH: shell.islandHeight
    property real islandR: shell.cornerRadius

    readonly property real panelWidth: 360
    readonly property int panelRadius: shell.cornerRadius > 0 ? 22 : 0
    readonly property int innerRadius: shell.cornerRadius > 0 ? 14 : 0
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.08)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.10)

    readonly property real e: io(reveal)
    readonly property real wP: io(reveal / 0.6)
    readonly property real hP: io((reveal - 0.15) / 0.85)
    readonly property real contentOpacity: smooth((reveal - 0.5) / 0.4)
    readonly property real curR: panelRadius > 0 ? islandR + (panelRadius - islandR) * hP : 0
    readonly property real fullW: Math.min(panelWidth, width - 80)
    readonly property real fullH: col.implicitHeight + 32

    readonly property var actions: [
        { id: "lock", icon: "\uf023", label: "Lock", danger: false, cmd: lockCommand },
        { id: "suspend", icon: "\uf186", label: "Suspend", danger: false, cmd: suspendCommand },
        { id: "logout", icon: "\uf2f5", label: "Logout", danger: false, cmd: logoutCommand },
        { id: "reboot", icon: "\uf021", label: "Reboot", danger: true, cmd: rebootCommand },
        { id: "shutdown", icon: "\uf011", label: "Shutdown", danger: true, cmd: shutdownCommand }
    ]

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || reveal > 0

    WlrLayershell.namespace: "island-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function clamp(v, a, b) {
        return Math.max(a, Math.min(b, v))
    }

    function smooth(t) {
        t = clamp(t, 0, 1)
        return t * t * (3 - 2 * t)
    }

    function io(t) {
        t = clamp(t, 0, 1)
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
    }

    function disarm() {
        armedAction = ""
        armTimer.stop()
    }

    function step(d) {
        const n = actions.length
        selected = selected < 0 ? (d > 0 ? 0 : n - 1) : (selected + d + n) % n
        disarm()
    }

    function trigger(action) {
        if (armedAction !== action.id) {
            armedAction = action.id
            armTimer.restart()
            return
        }
        disarm()
        win.shell.powermenuOpen = false
        execTimer.pendingCmd = action.cmd
        execTimer.restart()
    }

    Binding {
        target: win
        property: "islandW"
        value: win.shell.islandW
        when: !win.shell.barHidden && win.shell.islandW > 0
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: win
        property: "islandH"
        value: win.shell.islandH
        when: !win.shell.barHidden && win.shell.islandW > 0
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: win
        property: "islandR"
        value: win.shell.islandR
        when: !win.shell.barHidden && win.shell.islandW > 0
        restoreMode: Binding.RestoreNone
    }

    Behavior on reveal {
        NumberAnimation {
            duration: win.open ? win.openMs : win.closeMs
            easing.type: Easing.Linear
        }
    }

    Timer {
        id: armTimer
        interval: win.confirmMs
        onTriggered: win.disarm()
    }

    Timer {
        id: execTimer

        property string pendingCmd: ""

        interval: win.closeMs + 40
        onTriggered: {
            if (pendingCmd !== "") {
                Quickshell.execDetached(["sh", "-c", pendingCmd])
                pendingCmd = ""
            }
        }
    }

    Connections {
        target: win.shell

        function onPowermenuOpenChanged() {
            if (win.shell.powermenuOpen) {
                const m = Hyprland.focusedMonitor
                const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
                win.targetScreen = s || Quickshell.screens[0]
                win.shell.ccOpen = false
                win.shell.launcherOpen = false
                win.shell.dashboardOpen = false
                win.shell.clipboardOpen = false
                win.shell.wallpaperOpen = false
                win.disarm()
                win.selected = -1
                win.open = true
                Qt.callLater(() => keys.forceActiveFocus())
            } else {
                win.open = false
                win.disarm()
            }
        }

        function onCcOpenChanged() {
            if (win.shell.ccOpen)
                win.shell.powermenuOpen = false
        }

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen)
                win.shell.powermenuOpen = false
        }

        function onDashboardOpenChanged() {
            if (win.shell.dashboardOpen)
                win.shell.powermenuOpen = false
        }

        function onClipboardOpenChanged() {
            if (win.shell.clipboardOpen)
                win.shell.powermenuOpen = false
        }

        function onWallpaperOpenChanged() {
            if (win.shell.wallpaperOpen)
                win.shell.powermenuOpen = false
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.open
        onActivated: win.shell.powermenuOpen = false
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const k = event.key
            const n = k - Qt.Key_1

            if (n >= 0 && n < win.actions.length) {
                win.selected = n
                win.trigger(win.actions[n])
            } else if (k === Qt.Key_Right || k === Qt.Key_Tab || k === Qt.Key_L) {
                win.step(1)
            } else if (k === Qt.Key_Left || k === Qt.Key_Backtab || k === Qt.Key_H) {
                win.step(-1)
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                if (win.selected >= 0)
                    win.trigger(win.actions[win.selected])
            } else {
                return
            }
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: win.reveal > 0
        color: "#000000"
        opacity: 0.2 * win.e
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.powermenuOpen = false
    }

    ClippingRectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: shell.topMargin
        width: 2 * Math.round((win.islandW + (win.fullW - win.islandW) * win.wP) / 2)
        height: Math.round(win.islandH + (win.fullH - win.islandH) * win.hP)

        topLeftRadius: win.shell.notch ? 0 : win.curR
        topRightRadius: win.shell.notch ? 0 : win.curR
        bottomLeftRadius: win.curR
        bottomRightRadius: win.curR

        color: win.shell.barBg
        border.width: win.shell.notch ? 0 : 1
        border.color: Qt.alpha(win.shell.barFg, 0.08)

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            y: (1 - win.contentOpacity) * -6
            width: win.fullW
            height: win.fullH
            opacity: win.contentOpacity
            visible: opacity > 0.01
            enabled: win.open

            ColumnLayout {
                id: col
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: win.armedAction === "" ? "What would you like to do?" : "Press again to confirm"
                    color: win.armedAction === "" ? win.soft : win.accentText
                    font.family: shell.textFont
                    font.pixelSize: 11
                    font.bold: true

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Repeater {
                        model: win.actions

                        ColumnLayout {
                            id: btn

                            required property var modelData
                            required property int index

                            readonly property bool armed: win.armedAction === modelData.id
                            readonly property bool focused: win.selected === index
                            readonly property bool dangerColor: modelData.danger
                            readonly property color activeColor: dangerColor ? win.shell.accent : win.accentText
                            readonly property color idleColor: dangerColor ? Qt.alpha(win.shell.accent, 0.9) : win.shell.barFg
                            readonly property real a: win.smooth((win.reveal - 0.45 - index * 0.04) / 0.3)

                            spacing: 5
                            opacity: a
                            scale: 0.8 + 0.2 * a
                            transform: Translate { y: (1 - btn.a) * 14 }

                            Rectangle {
                                id: circle
                                Layout.alignment: Qt.AlignHCenter
                                width: 44
                                height: 44
                                radius: 22
                                scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse || btn.armed || btn.focused ? 1.1 : 1.0)
                                color: btn.armed
                                    ? btn.activeColor
                                    : (mouseArea.containsMouse || btn.focused ? Qt.alpha(win.shell.barFg, 0.14) : win.tileColor)
                                border.width: btn.armed || btn.focused ? 2 : 1
                                border.color: btn.armed
                                    ? btn.activeColor
                                    : (btn.focused ? Qt.alpha(btn.activeColor, 0.7) : win.borderColor)

                                Behavior on scale {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1 }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: btn.modelData.icon
                                    color: btn.armed ? win.shell.barBg : btn.idleColor
                                    font.family: shell.textFont
                                    font.pixelSize: 16

                                    Behavior on color {
                                        ColorAnimation { duration: 160 }
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: win.selected = btn.index
                                    onClicked: win.trigger(btn.modelData)
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: btn.modelData.label
                                color: btn.armed ? win.accentText : win.soft
                                font.family: shell.textFont
                                font.pixelSize: 9
                                font.bold: btn.armed

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 16
                                height: 16
                                radius: 5
                                color: btn.armed ? Qt.alpha(btn.activeColor, 0.25) : win.tileColor
                                border.width: 1
                                border.color: btn.armed ? btn.activeColor : win.borderColor

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: btn.index + 1
                                    color: btn.armed ? btn.activeColor : win.soft
                                    font.family: shell.textFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Shape {
        id: earL

        visible: win.shell.notch && width > 0.5
        anchors.top: panel.top
        anchors.right: panel.left
        width: win.curR
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

        visible: win.shell.notch && width > 0.5
        anchors.top: panel.top
        anchors.left: panel.right
        width: win.curR
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
