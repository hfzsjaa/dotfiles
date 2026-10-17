import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win

    required property var shell

    property bool open: false
    property string tag: "island-shade"
    property int panelWidth: 460
    property var siblings: []
    property var targetScreen: Quickshell.screens[0]

    property int openMs: shell.panelOpenMs || 520
    property int closeMs: shell.panelCloseMs || 380
    property real reveal: open ? 1 : 0

    property real islandW: 180
    property real islandH: shell.islandHeight
    property real islandR: shell.cornerRadius

    default property alias contentData: body.data
    readonly property ShadePalette pal: ShadePalette { shell: win.shell }

    readonly property bool notch: shell.notch
    readonly property real e: io(reveal)
    readonly property real wP: io(reveal / 0.6)
    readonly property real hP: io((reveal - 0.15) / 0.85)
    readonly property real contentOpacity: smooth((reveal - 0.5) / 0.4)
    readonly property real curR: pal.panelRadius > 0 ? islandR + (pal.panelRadius - islandR) * hP : 0
    readonly property real fullW: Math.min(panelWidth, width - 80)
    readonly property real fullH: Math.min(height - shell.topMargin - 24, scroll.contentHeight + 24)

    signal dismissed()

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

    WlrLayershell.namespace: tag
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

    onOpenChanged: {
        if (!open)
            return
        shell.ccOpen = false
        shell.launcherOpen = false
        shell.clipboardOpen = false
        for (const k of siblings)
            shell[k] = false
    }

    Binding {
        target: win
        property: "targetScreen"
        value: {
            const m = Hyprland.focusedMonitor
            const s = m ? Quickshell.screens.find(x => x.name === m.name) : null
            return s || Quickshell.screens[0]
        }
        when: !win.open && win.reveal === 0
        restoreMode: Binding.RestoreNone
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

    Connections {
        target: win.shell

        function onCcOpenChanged() {
            if (win.shell.ccOpen)
                win.dismissed()
        }

        function onLauncherOpenChanged() {
            if (win.shell.launcherOpen)
                win.dismissed()
        }

        function onClipboardOpenChanged() {
            if (win.shell.clipboardOpen)
                win.dismissed()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.open
        onActivated: win.dismissed()
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
        onClicked: win.dismissed()
    }

    ClippingRectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: win.shell.topMargin
        width: 2 * Math.round((win.islandW + (win.fullW - win.islandW) * win.wP) / 2)
        height: Math.round(win.islandH + (win.fullH - win.islandH) * win.hP)

        topLeftRadius: win.notch ? 0 : win.curR
        topRightRadius: win.notch ? 0 : win.curR
        bottomLeftRadius: win.curR
        bottomRightRadius: win.curR

        color: win.pal.bg
        border.width: win.notch ? 0 : 1
        border.color: win.pal.line

        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (1 - win.contentOpacity) * -6
            width: win.fullW
            height: win.fullH
            opacity: win.contentOpacity
            visible: opacity > 0.01

            Flickable {
                id: scroll
                anchors.fill: parent
                anchors.margins: 12
                contentWidth: width
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body
                    width: scroll.width
                    spacing: 14
                }
            }
        }
    }

    Shape {
        id: earL

        visible: win.notch && width > 0.5
        anchors.top: panel.top
        anchors.right: panel.left
        width: win.curR
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.pal.bg
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

        visible: win.notch && width > 0.5
        anchors.top: panel.top
        anchors.left: panel.right
        width: win.curR
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.pal.bg
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
