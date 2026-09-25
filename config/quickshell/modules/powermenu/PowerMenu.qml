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
    property var targetScreen: Quickshell.screens[0]

    property string lockCommand: "hyprlock"
    property string suspendCommand: "systemctl suspend"
    property string logoutCommand: "hyprctl dispatch exit"
    property string rebootCommand: "systemctl reboot"
    property string shutdownCommand: "systemctl poweroff"

    property int confirmMs: 2500
    property string armedAction: ""

    readonly property real panelWidth: 360
    readonly property real panelHeight: 128
    readonly property real baseWidth: 96

    readonly property int innerRadius: shell.cornerRadius > 0 ? 14 : 0
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color tileColor: Qt.alpha(shell.barFg, 0.08)
    readonly property color borderColor: Qt.alpha(shell.barFg, 0.10)

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
    visible: open || island.progress > 0.001

    WlrLayershell.namespace: "island-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function disarm() {
        armedAction = ""
        armTimer.stop()
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

    Timer {
        id: armTimer
        interval: win.confirmMs
        onTriggered: win.disarm()
    }

    Timer {
    id: execTimer
    property string pendingCmd: ""
    interval: 260
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
                win.open = true
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

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        onClicked: win.shell.powermenuOpen = false
    }

    Rectangle {
        id: island

        property real progress: win.open ? 1 : 0
        readonly property real p: Math.max(0, Math.min(1, progress))
        readonly property real r: win.shell.cornerRadius > 0 ? win.shell.cornerRadius + (20 - win.shell.cornerRadius) * p : 0

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
        border.color: Qt.alpha(win.shell.barFg, 0.08)
        clip: false

        Behavior on progress {
            NumberAnimation {
                duration: win.open ? 260 : 200
                easing.type: win.open ? Easing.OutQuint : Easing.InOutCubic
            }
        }

        Behavior on color {
            ColorAnimation { duration: 250 }
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.topMargin: win.shell.islandHeight + 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: win.panelWidth - 28
            opacity: Math.max(0, Math.min(1, (island.p - 0.5) / 0.35))
            enabled: win.open
            spacing: 8

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: win.armedAction === "" ? "What would you like to do?" : "Click again to confirm"
                color: win.armedAction === "" ? win.soft : win.accentText
                font.family: shell.textFont
                font.pixelSize: 11
                font.bold: true

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Repeater {
                    model: win.actions

                    ColumnLayout {
                        id: btn
                        required property var modelData
                        required property int index

                        readonly property bool armed: win.armedAction === modelData.id
                        readonly property bool dangerColor: modelData.danger
                        readonly property color idleColor: dangerColor ? Qt.alpha(win.shell.accent, 0.9) : win.shell.barFg

                        spacing: 4
                        opacity: 0
                        scale: 0.7

                        Component.onCompleted: popIn.start()

                        SequentialAnimation {
                            id: popIn
                            PauseAnimation { duration: btn.index * 28 }
                            ParallelAnimation {
                                NumberAnimation { target: btn; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                                NumberAnimation { target: btn; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                            }
                        }

                        Rectangle {
                            id: circle
                            Layout.alignment: Qt.AlignHCenter
                            width: 42
                            height: 42
                            radius: 21
                            scale: mouseArea.pressed ? 0.90 : (mouseArea.containsMouse || btn.armed ? 1.10 : 1.0)
                            color: btn.armed
                                ? (btn.dangerColor ? win.shell.accent : win.accentText)
                                : (mouseArea.containsMouse ? Qt.alpha(win.shell.barFg, 0.14) : win.tileColor)
                            border.width: btn.armed ? 2 : 1
                            border.color: btn.armed
                                ? (btn.dangerColor ? win.shell.accent : win.accentText)
                                : win.borderColor

                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                            }
                            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: btn.modelData.icon
                                color: btn.armed ? win.shell.barBg : btn.idleColor
                                font.family: shell.textFont
                                font.pixelSize: 15

                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
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

                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }
                }
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
