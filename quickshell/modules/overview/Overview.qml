import QtQml
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
    property bool panOnFocus: true
    property bool centerOnFocus: true
    property bool liveAll: true
    property int animMs: shell.panelOpenMs || 520
    property int closeMs: shell.panelCloseMs || 380
    property int viewMs: 150
    property int pollMs: 500
    property real minZoom: 0.04
    property real maxZoom: 1.5
    property real fitMaxZoom: 0.85
    property real fitMargin: 72
    property real nudgeStep: 120
    readonly property real minWinW: 120
    readonly property real minWinH: 80
    readonly property int handleSize: 6
    readonly property var edgeNames: ["L", "R", "T", "B", "LT", "RT", "LB", "RB"]
    readonly property bool open: shell.overviewOpen && shell.layoutMode === "float"
    readonly property bool settled: open && reveal > 0.995
    property real reveal: open ? 1 : 0
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property real viewZoom: zoom
    property real viewX: panX
    property real viewY: panY
    property bool animate: false
    property bool panning: false
    property string selAddr: ""
    property var targetScreen: Quickshell.screens[0]
    property real islandW: 180
    property real islandH: shell.islandHeight
    property real islandR: shell.cornerRadius
    readonly property bool isLight: shell.light === true
    readonly property int gap: Math.round(7 * (shell.uiScale || 1))
    readonly property real cardY: shell.topMargin + gap
    readonly property real e: io(reveal)
    readonly property real wP: io(reveal / 0.6)
    readonly property real hP: io((reveal - 0.15) / 0.85)
    readonly property real cardR: islandR > 0 ? (islandR + 10 * Math.sin(Math.PI * hP)) * (1 - hP) : 0
    readonly property real contentOpacity: smooth((reveal - 0.5) / 0.4)
    readonly property real hudP: smooth((reveal - 0.75) / 0.25)
    readonly property color cardColor: Qt.tint(shell.barBg, Qt.alpha("#000000", (isLight ? 0.08 : 0.34) * hP))
    readonly property var mon: Hyprland.monitorFor(targetScreen)
    readonly property var mo: mon && mon.lastIpcObject ? mon.lastIpcObject : null
    readonly property bool hasMon: mo !== null && mo.scale > 0
    readonly property real monX: mo ? mo.x : 0
    readonly property real monY: mo ? mo.y : 0
    readonly property real sw: hasMon ? mo.width / mo.scale : width
    readonly property real sh: hasMon ? mo.height / mo.scale : height
    readonly property int wsId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1
    readonly property string wallPath: String(shell.wallpaper || shell.wallpaperPath || shell.currentWallpaper || shell.wallpaperSource || "")
    readonly property string wallUrl: wallPath === "" ? "" : (wallPath.indexOf("://") >= 0 ? wallPath : "file://" + wallPath)
    readonly property var wins: open ? wsWindows() : []
    readonly property var bounds: calcBounds(wins)
    readonly property real gridStep: {
        let s = 120;
        while (s * viewZoom < 40)s *= 2
        return s;
    }
    readonly property color fg: shell.barFg
    readonly property color bg: shell.barBg
    readonly property color accent: shell.accentText || shell.main
    readonly property color deskTone: Qt.tint(shell.barBg, Qt.alpha(shell.barMain, isLight ? 0.1 : 0.08))
    readonly property color backdrop: Qt.tint(shell.barBg, Qt.alpha("#000000", isLight ? 0.08 : 0.34))
    readonly property real scrimAlpha: isLight ? 0.24 : 0.4
    readonly property color line: Qt.alpha(fg, 0.16)
    readonly property color dotColor: Qt.alpha(fg, 0.16)
    readonly property var keymap: [{
        "keys": ["Escape"],
        "run": () => {
            return shell.overviewOpen = false;
        }
    }, {
        "keys": ["0", "F"],
        "run": () => {
            return fit();
        }
    }, {
        "keys": ["1"],
        "run": () => {
            return actual();
        }
    }, {
        "keys": ["Space"],
        "run": () => {
            return toggleFit();
        }
    }, {
        "keys": ["+", "="],
        "run": () => {
            return zoomCenter(1.25);
        }
    }, {
        "keys": ["-"],
        "run": () => {
            return zoomCenter(0.8);
        }
    }, {
        "keys": ["Left", "A"],
        "run": () => {
            return nudge(nudgeStep, 0);
        }
    }, {
        "keys": ["Right", "D"],
        "run": () => {
            return nudge(-nudgeStep, 0);
        }
    }, {
        "keys": ["Up", "W"],
        "run": () => {
            return nudge(0, nudgeStep);
        }
    }, {
        "keys": ["Down", "S"],
        "run": () => {
            return nudge(0, -nudgeStep);
        }
    }, {
        "keys": ["Shift+Left", "Alt+Left"],
        "run": () => {
            return selectDir(-1, 0);
        }
    }, {
        "keys": ["Shift+Right", "Alt+Right"],
        "run": () => {
            return selectDir(1, 0);
        }
    }, {
        "keys": ["Shift+Up", "Alt+Up"],
        "run": () => {
            return selectDir(0, -1);
        }
    }, {
        "keys": ["Shift+Down", "Alt+Down"],
        "run": () => {
            return selectDir(0, 1);
        }
    }, {
        "keys": ["Tab"],
        "run": () => {
            return selectStep(1);
        }
    }, {
        "keys": ["Shift+Tab"],
        "run": () => {
            return selectStep(-1);
        }
    }, {
        "keys": ["Return", "Enter"],
        "run": () => {
            return openSelected();
        }
    }]

    function clamp(v, a, b) {
        return Math.max(a, Math.min(b, v));
    }

    function io(t) {
        t = clamp(t, 0, 1);
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
    }

    function smooth(t) {
        t = clamp(t, 0, 1);
        return t * t * (3 - 2 * t);
    }

    function outBack(t) {
        const c1 = 1.3, c3 = c1 + 1;
        t = clamp(t, 0, 1);
        return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
    }

    function rectOf(o) {
        return {
            "x": o.at[0] - monX,
            "y": o.at[1] - monY,
            "w": o.size[0],
            "h": o.size[1]
        };
    }

    function centerOf(o) {
        const r = rectOf(o);
        return {
            "x": r.x + r.w / 2,
            "y": r.y + r.h / 2
        };
    }

    function wsWindows() {
        return Hyprland.toplevels.values.map((t) => {
            return t.lastIpcObject;
        }).filter((o) => {
            return o && o.address && o.mapped !== false && o.workspace && o.workspace.id === wsId;
        });
    }

    function calcBounds(list) {
        let x0 = 0, y0 = 0, x1 = sw, y1 = sh;
        for (const o of list) {
            const r = rectOf(o);
            x0 = Math.min(x0, r.x);
            y0 = Math.min(y0, r.y);
            x1 = Math.max(x1, r.x + r.w);
            y1 = Math.max(y1, r.y + r.h);
        }
        return {
            "x0": x0,
            "y0": y0,
            "x1": x1,
            "y1": y1
        };
    }

    function activeAddr() {
        const t = Hyprland.activeToplevel;
        return t && t.lastIpcObject && t.lastIpcObject.address ? t.lastIpcObject.address : "";
    }

    function dispatch2(legacy, lua) {
        Hyprland.dispatch(legacy);
        Hyprland.dispatch(lua);
    }

    function moveTo(addr, x, y) {
        const rx = Math.round(x), ry = Math.round(y);
        dispatch2("movewindowpixel exact " + rx + " " + ry + ",address:" + addr, "hl.dsp.window.move({ x = " + rx + ", y = " + ry + ", relative = false, window = \"address:" + addr + "\" })");
    }

    function resizeTo(addr, w, h) {
        const rw = Math.round(clamp(w, minWinW, sw * 3));
        const rh = Math.round(clamp(h, minWinH, sh * 3));
        dispatch2("resizewindowpixel exact " + rw + " " + rh + ",address:" + addr, "hl.dsp.window.resize({ x = " + rw + ", y = " + rh + ", relative = false, window = \"address:" + addr + "\" })");
    }

    function closeWindow(addr) {
        dispatch2("closewindow address:" + addr, "hl.dsp.window.close({ window = \"address:" + addr + "\" })");
        refreshSoon.restart();
    }

    function placeRect(addr, x, y, w, h) {
        resizeTo(addr, w, h);
        moveTo(addr, x, y);
    }

    function fit() {
        const b = calcBounds(wsWindows());
        const bw = b.x1 - b.x0, bh = b.y1 - b.y0;
        zoom = clamp(Math.min((width - 2 * fitMargin) / bw, (height - 2 * fitMargin) / bh), minZoom, fitMaxZoom);
        panX = (width - bw * zoom) / 2 - b.x0 * zoom;
        panY = (height - bh * zoom) / 2 - b.y0 * zoom;
    }

    function actual() {
        zoom = 1;
        panX = (width - sw) / 2;
        panY = (height - sh) / 2;
    }

    function toggleFit() {
        if (Math.abs(zoom - 1) < 0.001)
            fit();
        else
            actual();
    }

    function zoomAt(mx, my, f) {
        const nz = clamp(zoom * f, minZoom, maxZoom);
        panX = mx - (mx - panX) * nz / zoom;
        panY = my - (my - panY) * nz / zoom;
        zoom = nz;
    }

    function zoomCenter(f) {
        zoomAt(width / 2, height / 2, f);
    }

    function nudge(dx, dy) {
        panX += dx;
        panY += dy;
    }

    function ensureVisible(o) {
        const r = rectOf(o);
        const m = 48;
        const x = panX + r.x * zoom, y = panY + r.y * zoom;
        if (x < m || y < m || x + r.w * zoom > width - m || y + r.h * zoom > height - m) {
            panX = width / 2 - (r.x + r.w / 2) * zoom;
            panY = height / 2 - (r.y + r.h / 2) * zoom;
        }
    }

    function choose(o) {
        selAddr = o.address;
        ensureVisible(o);
    }

    function selectStep(dir) {
        const list = wsWindows().sort((a, b) => {
            return (a.at[0] - b.at[0]) || (a.at[1] - b.at[1]);
        });
        if (list.length === 0)
            return ;

        let i = list.findIndex((o) => {
            return o.address === selAddr;
        });
        i = i < 0 ? (dir > 0 ? 0 : list.length - 1) : (i + dir + list.length) % list.length;
        choose(list[i]);
    }

    function selectDir(dx, dy) {
        const list = wsWindows();
        if (list.length === 0)
            return ;

        const cur = list.find((o) => {
            return o.address === selAddr;
        }) || list.find((o) => {
            return o.address === activeAddr();
        });
        if (!cur) {
            choose(list[0]);
            return ;
        }
        const c = centerOf(cur);
        let best = null;
        let bestScore = Infinity;
        for (const o of list) {
            if (o.address === cur.address)
                continue;

            const p = centerOf(o);
            const vx = p.x - c.x, vy = p.y - c.y;
            const along = vx * dx + vy * dy;
            if (along <= 0)
                continue;

            const across = Math.abs(vx * dy - vy * dx);
            const score = along + across * 2;
            if (score < bestScore) {
                bestScore = score;
                best = o;
            }
        }
        if (best)
            choose(best);

    }

    function openSelected() {
        const o = wsWindows().find((w) => {
            return w.address === selAddr;
        });
        if (o)
            focusWindow(o);

    }

    function focusWindow(o) {
        const r = rectOf(o);
        const hidden = r.x < 0 || r.y < 0 || r.x + r.w > sw || r.y + r.h > sh;
        if (panOnFocus && o.floating && (centerOnFocus || hidden)) {
            const dx = (sw - r.w) / 2 - r.x;
            const dy = (sh - r.h) / 2 - r.y;
            for (const w of wsWindows()) {
                if (!w.floating)
                    continue;

                const rr = rectOf(w);
                moveTo(w.address, rr.x + dx, rr.y + dy);
            }
        }
        Hyprland.dispatch("focuswindow address:" + o.address);
        shell.overviewOpen = false;
    }

    screen: targetScreen
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || reveal > 0
    WlrLayershell.namespace: "island-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onOpenChanged: {
        selAddr = "";
        panning = false;
        if (open) {
            animate = false;
            const f = Hyprland.focusedMonitor;
            const s = Quickshell.screens.find((x) => {
                return f && x.name === f.name;
            });
            if (s)
                targetScreen = s;

            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            actual();
            fitTimer.restart();
        } else {
            fitTimer.stop();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
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
        when: !win.shell.barHidden && win.shell.islandH > 0
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: win
        property: "islandR"
        value: win.shell.islandR
        when: !win.shell.barHidden && win.shell.islandW > 0
        restoreMode: Binding.RestoreNone
    }

    Timer {
        id: fitTimer

        interval: 120
        onTriggered: {
            win.actual();
            win.animate = true;
            win.selAddr = win.activeAddr();
        }
    }

    Timer {
        interval: win.pollMs
        running: win.open && !win.panning
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        id: refreshSoon

        interval: 80
        onTriggered: Hyprland.refreshToplevels()
    }

    Instantiator {
        model: win.keymap

        Shortcut {
            required property var modelData

            enabled: win.open
            sequences: modelData.keys
            onActivated: modelData.run()
        }

    }

    Rectangle {
        anchors.fill: parent
        visible: win.reveal < 1
        color: "#000000"
        opacity: win.scrimAlpha * win.e
    }

    ClippingRectangle {
        id: card

        width: 2 * Math.round((win.islandW + (win.width - win.islandW) * win.wP) / 2)
        height: Math.round(win.islandH + (win.height - win.islandH) * win.hP)
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.shell.topMargin * (1 - win.hP))
        topLeftRadius: win.shell.notch ? 0 : win.cardR
        topRightRadius: win.shell.notch ? 0 : win.cardR
        bottomLeftRadius: win.cardR
        bottomRightRadius: win.cardR
        color: win.cardColor
        border.width: win.shell.notch ? 0 : 1
        border.color: Qt.alpha(win.fg, 0.06 * (1 - win.hP))

        Item {
            id: view

            x: -card.x
            y: -card.y
            width: win.width
            height: win.height
            opacity: win.contentOpacity
            visible: opacity > 0.01

            Image {
                anchors.fill: parent
                z: -10
                scale: 1.08 - 0.08 * win.e
                transformOrigin: Item.Center
                source: win.wallUrl
                sourceSize.width: win.width
                sourceSize.height: win.height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: status === Image.Ready
            }

            MouseArea {
                id: stage

                property real sx: 0
                property real sy: 0
                property real px: 0
                property real py: 0
                property bool moved: false

                anchors.fill: parent
                scale: 1.05 - 0.05 * win.e
                transformOrigin: Item.Center
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: win.panning ? Qt.ClosedHandCursor : Qt.ArrowCursor
                onPressed: (m) => {
                    sx = m.x;
                    sy = m.y;
                    px = win.panX;
                    py = win.panY;
                    moved = false;
                }
                onPositionChanged: (m) => {
                    const dx = m.x - sx, dy = m.y - sy;
                    if (!moved && Math.hypot(dx, dy) < 4)
                        return ;

                    moved = true;
                    win.panning = true;
                    win.panX = px + dx;
                    win.panY = py + dy;
                }
                onReleased: win.panning = false
                onCanceled: win.panning = false
                onDoubleClicked: win.toggleFit()

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    acceptedModifiers: Qt.NoModifier
                    onWheel: (e) => {
                        return win.zoomAt(e.x, e.y, Math.pow(1.0015, e.angleDelta.y));
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    acceptedModifiers: Qt.ShiftModifier
                    onWheel: (e) => {
                        return win.nudge(e.angleDelta.x + e.angleDelta.y, 0);
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    acceptedModifiers: Qt.ControlModifier
                    onWheel: (e) => {
                        return win.nudge(0, e.angleDelta.y);
                    }
                }

                ClippingRectangle {
                    z: -3
                    x: win.viewX
                    y: win.viewY
                    width: win.sw * win.viewZoom
                    height: win.sh * win.viewZoom
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 0
                        border.color: Qt.alpha(win.accent, 0.35)
                    }

                }

                Repeater {
                    model: Hyprland.toplevels

                    Tile {
                        required property var modelData

                        toplevel: modelData
                    }

                }

            }

            Pill {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 14 - (1 - win.hudP) * 20
                opacity: win.hudP
                implicitHeight: 34
                implicitWidth: hud.implicitWidth + 12

                RowLayout {
                    id: hud

                    anchors.centerIn: parent
                    spacing: 2

                    HudButton {
                        label: "\u2212"
                        onClicked: win.zoomCenter(0.8)
                    }

                    Text {
                        Layout.preferredWidth: 46
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(win.viewZoom * 100) + "%"
                        color: win.fg
                        font.family: win.shell.textFont
                        font.pixelSize: 11
                    }

                    HudButton {
                        label: "+"
                        onClicked: win.zoomCenter(1.25)
                    }

                    HudButton {
                        label: "Fit"
                        onClicked: win.fit()
                    }

                    HudButton {
                        label: "1:1"
                        onClicked: win.actual()
                    }

                }

            }

        }

    }

    Shape {
        id: earL

        visible: win.shell.notch && width > 0.5
        x: card.x - width
        y: card.y
        width: win.cardR
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.cardColor
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
        x: card.x + card.width
        y: card.y
        width: win.cardR
        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: win.cardColor
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

    Behavior on reveal {
        NumberAnimation {
            duration: win.open ? win.animMs : win.closeMs
            easing.type: Easing.Linear
        }

    }

    component Ease: NumberAnimation {
        duration: win.viewMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: win.shell.easeOut
    }

    Behavior on viewZoom {
        enabled: win.animate && !win.panning

        Ease {
        }

    }

    Behavior on viewX {
        enabled: win.animate && !win.panning

        Ease {
        }

    }

    Behavior on viewY {
        enabled: win.animate && !win.panning

        Ease {
        }

    }

    component Pill: Rectangle {
        implicitHeight: 28
        color: Qt.alpha(win.bg, 0.72)
        border.width: 1
        border.color: win.line

        MouseArea {
            anchors.fill: parent
        }

    }

    component HudButton: Rectangle {
        id: b

        property string label: ""
        property bool active: false

        signal clicked()

        implicitWidth: Math.max(28, lbl.implicitWidth + 20)
        implicitHeight: 24
        color: hudArea.containsMouse ? Qt.alpha(win.fg, 0.14) : (active ? Qt.alpha(win.accent, 0.2) : "transparent")

        Text {
            id: lbl

            anchors.centerIn: parent
            text: b.label
            color: hudArea.containsMouse || b.active ? win.accent : win.fg
            font.family: win.shell.textFont
            font.pixelSize: 11
        }

        MouseArea {
            id: hudArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }

    }

    component Tile: Item {
        id: tile

        required property var toplevel
        readonly property var o: toplevel.lastIpcObject
        readonly property bool shown: !!(o && o.address && o.mapped !== false && o.workspace && o.workspace.id === win.wsId && win.reveal > 0)
        readonly property bool canEdit: shown && o.floating === true
        readonly property bool isActive: Hyprland.activeToplevel === toplevel
        readonly property bool isSel: shown && o.address === win.selAddr
        readonly property bool hovered: hover.hovered
        readonly property bool busy: dragging || resizing
        readonly property bool highlight: isSel || busy
        readonly property bool inView: x < win.width + 160 && y < win.height + 160 && x + width > -160 && y + height > -160
        readonly property int rank: shown && o.focusHistoryID !== undefined ? Math.min(Math.max(o.focusHistoryID, 0), 8) : 0
        readonly property real wx: shown ? o.at[0] - win.monX : 0
        readonly property real wy: shown ? o.at[1] - win.monY : 0
        readonly property real ww: shown ? o.size[0] : 0
        readonly property real wh: shown ? o.size[1] : 0
        readonly property string sig: wx + "," + wy + "," + ww + "," + wh
        readonly property string cls: shown ? (o.class || "") : ""
        readonly property var entry: cls !== "" ? DesktopEntries.heuristicLookup(cls) : null
        readonly property string iconSource: shown ? Quickshell.iconPath(entry && entry.icon ? entry.icon : cls.toLowerCase(), "application-x-executable") : ""
        readonly property string titleStr: shown ? (o.title || o.class || "") : ""
        readonly property real appearT: win.clamp((win.reveal - 0.5 - rank * 0.0125) / 0.4, 0, 1)
        readonly property real appear: shown ? (win.open ? win.outBack(appearT) : win.smooth(appearT)) : 0
        property real lift: (hovered && !busy) ? 1 : 0
        property real offX: 0
        property real offY: 0
        property real gl: 0
        property real gt: 0
        property real gr: 0
        property real gb: 0
        property bool dragging: false
        property bool resizing: false

        function reset() {
            offX = offY = gl = gt = gr = gb = 0;
        }

        function commitResize() {
            const z = win.viewZoom;
            win.placeRect(o.address, wx + (offX + gl) / z, wy + (offY + gt) / z, ww + (gr - gl) / z, wh + (gb - gt) / z);
            settle.restart();
            refreshSoon.restart();
        }

        visible: shown && inView && appear > 0.001
        x: win.viewX + wx * win.viewZoom + offX + gl
        y: win.viewY + wy * win.viewZoom + offY + gt
        width: Math.max(2, ww * win.viewZoom - gl + gr)
        height: Math.max(2, wh * win.viewZoom - gt + gb)
        z: busy ? 99999 : (isSel ? 50000 : (shown && o.focusHistoryID !== undefined ? 1000 - o.focusHistoryID : 1))
        opacity: (busy ? 0.9 : 1) * win.clamp(appear, 0, 1)
        scale: (0.86 + 0.14 * appear) * (1 + 0.015 * lift)
        transformOrigin: Item.Center
        transform: Translate {
            y: (1 - tile.appear) * 28
        }
        onSigChanged: {
            if (!busy)
                reset();

        }

        Behavior on lift {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }

        }

        HoverHandler {
            id: hover
        }

        Timer {
            id: settle

            interval: 700
            onTriggered: {
                if (!tile.busy)
                    tile.reset();

            }
        }

        Loader {
            anchors.fill: parent
            active: tile.shown
            asynchronous: true
            sourceComponent: body
        }

        Component {
            id: body

            Item {
                ClippingRectangle {
                    anchors.fill: parent
                    color: Qt.tint(win.deskTone, Qt.alpha(win.fg, 0.06))

                    ScreencopyView {
                        id: sc

                        anchors.fill: parent
                        captureSource: tile.toplevel.wayland
                        live: win.settled && tile.inView && (win.liveAll || tile.isActive || tile.hovered || tile.busy)
                    }

                    Timer {
                        interval: sc.hasContent ? 1000 : 120
                        running: win.open && tile.visible && !sc.live && sc.captureSource !== null
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: sc.captureFrame()
                    }

                    IconImage {
                        readonly property real size: Math.min(64, Math.max(14, Math.min(tile.width, tile.height) / 3))

                        anchors.centerIn: parent
                        implicitWidth: size
                        implicitHeight: size
                        source: tile.iconSource
                        visible: !sc.hasContent && parent.width > 24 && tile.iconSource !== ""
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.alpha(win.fg, 0.06)
                        visible: tile.hovered && !tile.busy
                    }

                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: tile.hovered ? 1 : 0
                    border.color: Qt.alpha(win.fg, 0.6)
                }

                MouseArea {
                    property real sx: 0
                    property real sy: 0
                    property bool moved: false

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: tile.dragging ? Qt.ClosedHandCursor : (tile.canEdit ? Qt.OpenHandCursor : Qt.PointingHandCursor)
                    onPressed: (m) => {
                        const p = mapToItem(tile.parent, m.x, m.y);
                        sx = p.x;
                        sy = p.y;
                        moved = false;
                        win.selAddr = tile.o.address;
                    }
                    onPositionChanged: (m) => {
                        if (!pressed || pressedButtons & Qt.MiddleButton)
                            return ;

                        const p = mapToItem(tile.parent, m.x, m.y);
                        const dx = p.x - sx, dy = p.y - sy;
                        if (!moved && Math.hypot(dx, dy) < 5)
                            return ;

                        moved = true;
                        if (tile.canEdit) {
                            tile.dragging = true;
                            tile.offX = dx;
                            tile.offY = dy;
                        }
                    }
                    onReleased: (m) => {
                        if (m.button === Qt.MiddleButton) {
                            win.closeWindow(tile.o.address);
                        } else if (tile.dragging) {
                            tile.dragging = false;
                            win.moveTo(tile.o.address, tile.wx + tile.offX / win.viewZoom, tile.wy + tile.offY / win.viewZoom);
                            settle.restart();
                            refreshSoon.restart();
                        } else if (!moved) {
                            win.focusWindow(tile.o);
                        }
                    }
                    onCanceled: tile.dragging = false
                }

                Rectangle {
                    id: chip

                    visible: tile.width > 90 && tile.height > 50
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 6
                    height: 20
                    width: Math.min(tile.width - 44, tm.advanceWidth + 16 + (tile.iconSource !== "" ? 20 : 0))
                    color: Qt.alpha(win.bg, 0.78)

                    TextMetrics {
                        id: tm

                        font.family: win.shell.textFont
                        font.pixelSize: 10
                        text: tile.titleStr
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 6

                        IconImage {
                            visible: tile.iconSource !== ""
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            implicitWidth: 14
                            implicitHeight: 14
                            source: tile.iconSource
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: tile.titleStr
                            color: tile.highlight || tile.isActive ? win.accent : win.fg
                            font.family: win.shell.textFont
                            font.pixelSize: 10
                        }

                    }

                }

                Rectangle {
                    id: closeBtn

                    visible: tile.hovered && !tile.busy && tile.width > 60 && tile.height > 40
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    width: 20
                    height: 20
                    color: closeArea.containsMouse ? Qt.alpha(win.shell.accent, 0.9) : Qt.alpha(win.bg, 0.78)

                    Text {
                        anchors.centerIn: parent
                        text: "\u2715"
                        color: closeArea.containsMouse ? win.bg : win.fg
                        font.family: win.shell.textFont
                        font.pixelSize: 9
                    }

                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.closeWindow(tile.o.address)
                    }

                }

                Repeater {
                    model: tile.canEdit && tile.width > 28 && tile.height > 28 ? win.edgeNames : []

                    Handle {
                        required property string modelData

                        owner: tile
                        edges: modelData
                    }

                }

            }

        }

    }

    component Handle: MouseArea {
        id: h

        required property var owner
        required property string edges
        readonly property bool eL: edges.indexOf("L") >= 0
        readonly property bool eR: edges.indexOf("R") >= 0
        readonly property bool eT: edges.indexOf("T") >= 0
        readonly property bool eB: edges.indexOf("B") >= 0
        readonly property bool corner: edges.length === 2
        readonly property bool horizontal: eL || eR
        readonly property real s: win.handleSize
        property real sx: 0
        property real sy: 0

        x: corner ? (eL ? -s : owner.width - 10) : (eL ? -s / 2 : (eR ? owner.width - s / 2 : 10))
        y: corner ? (eT ? -s : owner.height - 10) : (eT ? -s / 2 : (eB ? owner.height - s / 2 : 10))
        width: corner ? 10 + s : (horizontal ? s : owner.width - 20)
        height: corner ? 10 + s : (horizontal ? owner.height - 20 : s)
        acceptedButtons: Qt.LeftButton
        cursorShape: {
            if ((eL && eT) || (eR && eB))
                return Qt.SizeFDiagCursor;

            if ((eR && eT) || (eL && eB))
                return Qt.SizeBDiagCursor;

            return horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor;
        }
        onPressed: (m) => {
            const p = mapToItem(owner.parent, m.x, m.y);
            sx = p.x;
            sy = p.y;
            owner.resizing = true;
        }
        onPositionChanged: (m) => {
            if (!pressed)
                return ;

            const p = mapToItem(owner.parent, m.x, m.y);
            const dx = p.x - sx, dy = p.y - sy;
            const z = win.viewZoom;
            const w0 = owner.ww * z, h0 = owner.wh * z;
            const minW = Math.min(win.minWinW, owner.ww) * z;
            const minH = Math.min(win.minWinH, owner.wh) * z;
            if (eL)
                owner.gl = Math.min(dx, w0 - minW);

            if (eR)
                owner.gr = Math.max(dx, minW - w0);

            if (eT)
                owner.gt = Math.min(dy, h0 - minH);

            if (eB)
                owner.gb = Math.max(dy, minH - h0);

        }
        onReleased: {
            owner.resizing = false;
            owner.commitResize();
        }
        onCanceled: owner.resizing = false

        Rectangle {
            visible: h.corner && (h.owner.hovered || h.owner.resizing)
            x: (h.eL ? h.s : 10) - 3
            y: (h.eT ? h.s : 10) - 3
            width: 6
            height: 6
            color: win.accent
        }

    }

}
