import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.modules.notifications
import qs.modules.tray
import qs.modules.island.comp

PanelWindow {
    id: win

    required property var shell
    required property var modelData

    readonly property int stripH: 6
    readonly property int stripW: 120
    readonly property bool focusedHere: {
        const m = Hyprland.focusedMonitor
        return !m || m.name === modelData.name
    }
    readonly property bool notifying: !shell.ccOpen && shell.current !== null && focusedHere
    readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    screen: modelData
    anchors.top: true
    margins.top: shell.topMargin
    implicitWidth: 1400
    implicitHeight: 360
    exclusiveZone: stripH + shell.topMargin
    color: "transparent"
    mask: Region {
        item: hit
        Region { item: tray }
    }

    WlrLayershell.namespace: "island"
    WlrLayershell.keyboardFocus: wifiPage.typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Binding {
        target: win.shell
        property: "islandW"
        value: island.width
        when: win.focusedHere && !win.shell.barHidden
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: win.shell
        property: "islandH"
        value: island.height
        when: win.focusedHere && !win.shell.barHidden
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: win.shell
        property: "islandR"
        value: island.r
        when: win.focusedHere && !win.shell.barHidden
        restoreMode: Binding.RestoreNone
    }

    Connections {
        target: win.shell

        function onBarHiddenChanged() {
            if (win.shell.barHidden)
                island.page = "idle"
        }
    }

    WifiService {
        id: wifiSvc
    }

    BluetoothService {
        id: btSvc
    }

    component SizeAnim: NumberAnimation {
        duration: island.sizeMs
        easing.type: island.sizeEase
        easing.overshoot: 0.6
    }

    Rectangle {
        id: island

        property bool expanded: false
        property var shown: null
        property string page: "idle"
        property bool naturalScroll: true
        property real wheelX: 0
        property real wheelY: 0
        property bool wheelLock: false
        readonly property bool osdMode: win.shell.osdShowing && win.focusedHere
        property bool toastShowing: false
        property string toastIcon: ""
        property string toastText: ""
        readonly property bool toastMode: !osdMode && toastShowing && win.focusedHere
        readonly property string mode: osdMode ? "osd" : (toastMode ? "toast" : (page !== "idle" ? "page" : "idle"))
        readonly property bool allowVertical: page === "idle" || page === "music"
        readonly property bool hasNotif: win.shell.notifs.length > 0 && !win.shell.dnd
        readonly property var activePage: page === "stats" ? statsPage
            : (page === "control" ? controlPage
            : (page === "wifi" ? wifiPage
            : (page === "bluetooth" ? btPage
            : (page === "capture" ? capturePage
            : (page === "music" ? musicPage : null)))))
        readonly property int beadIdx: page === "stats" ? 0
            : ((page === "control" || page === "wifi" || page === "bluetooth") ? 1
            : (page === "capture" ? 2 : -1))
        readonly property bool open: expanded || mode !== "idle"
        property real openP: open ? 1 : 0
        property real progress: (osdMode || toastMode) ? 1 : 0
        property real pageP: mode === "page" ? 1 : 0
        property real base: content.implicitWidth + 12
        readonly property int pagePad: 26
        readonly property real pageW: activePage ? activePage.pageWidth : base
        readonly property real pageH: activePage ? activePage.implicitHeight + pagePad : 0
        readonly property real idleW: expanded ? base : win.stripW + (hasNotif ? 28 : 0)
        readonly property real idleH: expanded ? win.shell.islandHeight : win.stripH
        readonly property real targetW: mode === "osd" ? 200 : (mode === "toast" ? toastView.implicitWidth + 28 : (mode === "page" ? pageW : idleW))
        readonly property real targetH: mode === "osd" ? Math.max(osdView.implicitHeight, win.shell.islandHeight)
            : (mode === "toast" ? Math.max(toastView.implicitHeight, win.shell.islandHeight)
            : (mode === "page" ? pageH : idleH))
        property real w: targetW
        property real h: targetH
        readonly property real p: Math.max(0, Math.min(1, progress))
        readonly property real rp: Math.max(p, pageP)
        readonly property int sizeMs: mode === "toast" ? 320 : (mode === "page" ? 400 : (mode === "idle" ? (expanded ? 320 : 240) : 260))
        readonly property int sizeEase: (mode === "page" || mode === "toast" || (mode === "idle" && expanded)) ? Easing.OutBack : Easing.OutExpo
        readonly property real r: win.shell.cornerRadius > 0
            ? Math.min(h / 2, win.shell.cornerRadius + (28 - win.shell.cornerRadius) * rp)
            : 0

        function swipe(dir) {
            if (osdMode)
                return
            if (page === "idle") {
                if (dir === "left")
                    page = "stats"
                else if (dir === "right")
                    page = "control"
                else if (dir === "down")
                    page = "music"
            } else if (page === "stats" && dir === "right") {
                page = "idle"
            } else if (page === "control" && dir === "left") {
                page = "idle"
            } else if (page === "control" && dir === "right") {
                page = "capture"
            } else if (page === "capture" && dir === "left") {
                page = "control"
            } else if ((page === "wifi" || page === "bluetooth") && dir === "left") {
                page = "control"
            } else if (page === "music" && dir === "up") {
                page = "idle"
            }
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: w
        height: h

        topLeftRadius: win.shell.notch ? 0 : r
        topRightRadius: win.shell.notch ? 0 : r
        bottomLeftRadius: r
        bottomRightRadius: r

        color: Qt.tint(win.shell.barBg, Qt.alpha(win.shell.barFg, 0.05))
        border.width: win.shell.notch ? 0 : 1
        border.color: Qt.alpha(win.shell.barFg, (0.06 + 0.06 * rp) * openP)
        clip: true
        opacity: win.shell.barHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Behavior on w {
            SizeAnim {}
        }

        Behavior on h {
            SizeAnim {}
        }

        Behavior on openP {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Behavior on pageP {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Behavior on progress {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuart
            }
        }

        Connections {
            target: win.shell
            function onCurrentChanged() {
                if (win.shell.current)
                    island.shown = win.shell.current
            }
        }

        onShownChanged: swap.restart()

        Timer {
            id: collapseTimer
            interval: 280
            onTriggered: island.expanded = false
        }

        Timer {
            id: pageTimer
            interval: 900
            onTriggered: {
                if (!wifiPage.typing)
                    island.page = "idle"
            }
        }

        Timer {
            id: wheelReset
            interval: 220
            onTriggered: {
                island.wheelX = 0
                island.wheelY = 0
            }
        }

        Timer {
            id: wheelUnlock
            interval: 450
            onTriggered: island.wheelLock = false
        }

        Timer {
            id: toastTimer
            interval: 1900
            onTriggered: island.toastShowing = false
        }

        Connections {
            target: win.shell.capture
            ignoreUnknownSignals: true

            function onNotice(icon, text) {
                if (!win.focusedHere)
                    return
                island.toastIcon = icon
                island.toastText = text
                island.toastShowing = true
                toastTimer.restart()
            }
        }

        NumberAnimation {
            id: swap
            target: notifView
            property: "opacity"
            from: 0
            to: 1
            duration: 140
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                if (island.mode !== "idle")
                    return
                if (m.button === Qt.RightButton)
                    win.shell.barStyle = win.shell.notch ? "dynamic" : "notch"
                else
                    win.shell.dashboardOpen = !win.shell.dashboardOpen
            }
        }

        DragHandler {
            id: drag

            property bool fired: false

            target: null
            acceptedButtons: Qt.LeftButton
            yAxis.enabled: island.allowVertical
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything

            onActiveChanged: {
                if (active)
                    fired = false
            }

            onActiveTranslationChanged: {
                if (!active || fired)
                    return
                const dx = activeTranslation.x
                const dy = activeTranslation.y
                let dir = ""
                if (Math.abs(dx) > 28 && Math.abs(dx) >= Math.abs(dy))
                    dir = dx < 0 ? "left" : "right"
                else if (Math.abs(dy) > 20 && Math.abs(dy) > Math.abs(dx))
                    dir = dy > 0 ? "down" : "up"
                if (dir === "")
                    return
                fired = true
                island.swipe(dir)
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                if (island.wheelLock)
                    return
                island.wheelX += e.angleDelta.x
                island.wheelY += e.angleDelta.y
                wheelReset.restart()
                const k = island.naturalScroll ? 1 : -1
                const ax = island.wheelX * k
                const ay = island.wheelY * k
                let dir = ""
                if (Math.abs(ax) > 160 && Math.abs(ax) > Math.abs(ay))
                    dir = ax < 0 ? "left" : "right"
                else if (Math.abs(ay) > 160 && island.allowVertical && Math.abs(ay) > Math.abs(ax))
                    dir = ay > 0 ? "down" : "up"
                if (dir === "")
                    return
                island.wheelX = 0
                island.wheelY = 0
                island.wheelLock = true
                wheelUnlock.restart()
                island.swipe(dir)
            }
        }

        IdleContent {
            id: content
            shell: win.shell
            capture: win.shell.capture
            expanded: island.expanded
            anchors.centerIn: parent
            opacity: Math.max(0, 1 - Math.max(island.p, island.pageP) * 3) * Math.max(0, Math.min(1, (island.openP - 0.45) / 0.55))
            enabled: island.mode === "idle" && island.expanded
        }

        StatsPage {
            id: statsPage
            shell: win.shell
            current: island.page
            suppressed: island.mode !== "page"
        }

        ControlPage {
            id: controlPage
            shell: win.shell
            wifi: wifiSvc
            bt: btSvc
            current: island.page
            suppressed: island.mode !== "page"
            onOpenWifi: island.page = "wifi"
            onOpenBluetooth: island.page = "bluetooth"
        }

        CapturePage {
            id: capturePage
            shell: win.shell
            current: island.page
            suppressed: island.mode !== "page"
            onDone: island.page = "idle"
        }

        WifiPage {
            id: wifiPage
            shell: win.shell
            wifi: wifiSvc
            current: island.page
            suppressed: island.mode !== "page"
            onBack: island.page = "control"
        }

        BluetoothPage {
            id: btPage
            shell: win.shell
            bt: btSvc
            current: island.page
            suppressed: island.mode !== "page"
            onBack: island.page = "control"
        }

        MusicPage {
            id: musicPage
            shell: win.shell
            current: island.page
            suppressed: island.mode !== "page"
        }

        Item {
            id: bead
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: 32
            height: 4
            enabled: false
            opacity: island.beadIdx >= 0 ? island.pageP : 0
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Connections {
                target: island

                function onBeadIdxChanged() {
                    stretch.restart()
                }
            }

            Repeater {
                model: 3

                Rectangle {
                    x: index * 14
                    width: 4
                    height: 4
                    radius: 2
                    color: win.shell.barFg
                    opacity: 0.18
                }
            }

            Rectangle {
                id: cursor

                property real sx: 1

                x: Math.max(0, island.beadIdx) * 14 - 3
                width: 10
                height: 4
                radius: 2
                color: win.shell.accentText
                transform: Scale {
                    origin.x: cursor.width / 2
                    xScale: cursor.sx
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.9
                    }
                }

                SequentialAnimation {
                    id: stretch
                    NumberAnimation { target: cursor; property: "sx"; to: 2.4; duration: 120; easing.type: Easing.OutQuad }
                    NumberAnimation { target: cursor; property: "sx"; to: 1; duration: 260; easing.type: Easing.OutBack }
                }
            }
        }

        Item {
            anchors.fill: parent
            enabled: false
            visible: opacity > 0.001
            opacity: island.toastMode ? Math.max(0, Math.min(1, (island.p - 0.25) / 0.4)) : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            ToastView {
                id: toastView
                anchors.centerIn: parent
                shell: win.shell
                icon: island.toastIcon
                text: island.toastText
            }
        }

        Item {
            anchors.fill: parent
            enabled: island.osdMode
            visible: opacity > 0.001
            opacity: island.osdMode ? Math.max(0, Math.min(1, (island.p - 0.25) / 0.4)) : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            OsdView {
                id: osdView
                anchors.centerIn: parent
                width: parent.width - 24
                shell: win.shell
                audio: win.audio
            }
        }
    }

    Item {
        id: hit
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: win.shell.barHidden ? 0 : Math.max(island.width, win.stripW + 40)
        height: win.shell.barHidden ? 0 : Math.max(island.height, 14)

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop()
                    pageTimer.stop()
                    island.expanded = true
                } else {
                    collapseTimer.restart()
                    if (island.page !== "idle")
                        pageTimer.restart()
                }
            }
        }
    }

    PanelWindow {
        id: notifWin

        screen: win.modelData
        anchors.bottom: true
        margins.bottom: 0
        implicitWidth: win.shell.notifWidth + 48
        implicitHeight: 400
        exclusiveZone: 0
        color: "transparent"
        visible: notifBox.p > 0.001
        mask: Region { item: notifBox }

        WlrLayershell.namespace: "island-notif"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: notifBox

            readonly property bool active: win.notifying
            readonly property bool closing: !!island.shown && island.shown.closing
            readonly property bool critical: !!island.shown && active && island.shown.critical
            property real p: active ? 1 : 0

            Behavior on p {
                NumberAnimation {
                    duration: notifBox.active ? win.shell.morphMs : win.shell.dismissMs
                    easing.type: notifBox.active ? Easing.OutBack : Easing.InOutCubic
                    easing.overshoot: 0.5
                }
            }

            opacity: Math.max(0, Math.min(1, p))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (win.shell.notch ? 0 : 24) - (1 - p) * 24
            width: win.shell.notifWidth
            height: Math.max(notifView.implicitHeight, 40)
            topLeftRadius: 24
            topRightRadius: 24
            bottomLeftRadius: win.shell.notch ? 0 : 24
            bottomRightRadius: win.shell.notch ? 0 : 24
            color: Qt.tint(win.shell.barBg, Qt.alpha(win.shell.barFg, 0.05))
            border.width: (critical || !win.shell.notch) ? 1 : 0
            border.color: critical ? win.shell.accent : Qt.alpha(win.shell.barFg, 0.10)
            clip: true

            NotifCard {
                id: notifView
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: notifBox.closing ? win.shell.notifWidth * 0.3 * (1 - notifBox.p) : 0
                width: win.shell.notifWidth
                enabled: notifBox.active
                shell: win.shell
                entry: island.shown
                popup: true
                more: Math.max(0, win.shell.popups.length - 1)
            }
        }
    }

    Shape {
        id: earL
        visible: win.shell.notch
        anchors.top: parent.top
        anchors.right: island.left
        width: island.r
        height: width
        preferredRendererType: Shape.CurveRenderer
        opacity: win.shell.barHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        ShapePath {
            fillColor: island.color
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
        anchors.top: parent.top
        anchors.left: island.right
        width: island.r
        height: width
        preferredRendererType: Shape.CurveRenderer
        opacity: win.shell.barHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        ShapePath {
            fillColor: island.color
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
        shell: win.shell
        host: win
        anchors.top: parent.top
        anchors.right: island.left
        anchors.rightMargin: win.shell.notch ? win.shell.cornerRadius + 8 : 8
        enabled: !win.shell.barHidden
        opacity: win.shell.barHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }
}