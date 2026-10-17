import QtQuick
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: root

    required property LockContext context
    property var shell: null
    property string animation: "fire"
    property int attempts: 0
    property string armedName: ""
    property bool reveal: false
    property bool cursorOn: true
    property real appear: 0
    property real leave: 0
    property real spike: 0
    property real smoothLevel: level

    readonly property color bg: shell ? shell.barBg : "#101014"
    readonly property color fg: shell ? shell.barFg : "#e6e6e6"
    readonly property color accent: shell ? shell.emph(shell.barMain, 1.25) : "#9fd4e6"
    readonly property color errorColor: shell ? shell.accent : "#e06c75"
    readonly property string mono: shell ? shell.textFont : "monospace"

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property bool failed: context.showFailure
    readonly property bool busy: context.unlockInProgress
    readonly property bool leaving: !!(shell && shell.lockLeaving)
    readonly property int typed: passwordBox.text.length
    readonly property real enterBg: ease(seg(appear, 0, 0.45))
    readonly property real enterBar: ease(seg(appear, 0.35, 1))
    readonly property real enterW: ease(seg(appear, 0.2, 0.5))
    readonly property real enterH: ease(seg(appear, 0.4, 0.85))
    readonly property real enterText: seg(appear, 0.75, 1)
    readonly property real exitText: seg(leave, 0, 0.25)
    readonly property real exitH: easeIn(seg(leave, 0, 0.5))
    readonly property real exitW: easeIn(seg(leave, 0.4, 0.75))
    readonly property real exitBox: seg(leave, 0.7, 0.9)
    readonly property real exitBar: ease(seg(leave, 0.1, 0.6))
    readonly property real exitBg: ease(seg(leave, 0.45, 1))
    readonly property real fireScale: enterBg * (1 - exitBg)
    readonly property real level: 9 + Math.min(typed, 10) * 1.4 + spike

    readonly property int fs: Math.round(Math.max(14, Math.min(22, height / 58)))
    readonly property real cw: metrics.advanceWidth
    readonly property real lh: Math.ceil(metrics.height)

    readonly property int boxCols: 42
    readonly property int boxRows: 9
    readonly property int valueCol: 14
    readonly property int fieldCols: boxCols - valueCol - 2
    readonly property real boxW: boxCols * cw
    readonly property real boxH: boxRows * lh

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: !!bat && bat.isPresent
    readonly property real batFraction: {
        if (!hasBat)
            return 0;
        const p = bat.percentage;
        return Math.max(0, Math.min(1, p <= 1 ? p : p / 100));
    }
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property var player: shell ? shell.player : null
    readonly property int notifCount: shell && shell.notifs ? shell.notifs.length : 0

    function seg(v, a, b) {
        return Math.max(0, Math.min(1, (v - a) / (b - a)));
    }

    function ease(t) {
        return 1 - Math.pow(1 - t, 3);
    }

    function easeIn(t) {
        return t * t * t;
    }

    function tail(s, n) {
        return s.length > n ? s.slice(s.length - n) : s;
    }

    function frameLine(i) {
        const inner = boxCols - 2;
        if (i === 0) {
            const t = "\u2500[ locked ]";
            return "\u250c" + t + "\u2500".repeat(inner - t.length) + "\u2510";
        }
        if (i === boxRows - 1)
            return "\u2514" + "\u2500".repeat(inner) + "\u2518";
        return "\u2502" + " ".repeat(inner) + "\u2502";
    }

    function maskText() {
        const n = fieldCols - 1;
        return reveal ? tail(passwordBox.text, n) : "*".repeat(Math.min(typed, n));
    }

    function statusText() {
        if (armedName !== "")
            return "press again to " + armedName;
        if (leaving)
            return "welcome back, " + userName;
        if (busy)
            return "authenticating...";
        if (failed)
            return "authentication failed" + (attempts > 1 ? " (" + attempts + ")" : "");
        if (typed > 0)
            return "press enter to unlock";
        return "session locked";
    }

    function statusColor() {
        if (armedName !== "" || (failed && !busy))
            return errorColor;
        if (leaving || busy)
            return accent;
        return Qt.alpha(fg, 0.55);
    }

    function power(name, cmd) {
        if (armedName === name) {
            armedName = "";
            Quickshell.execDetached(cmd);
        } else {
            armedName = name;
            armTimer.restart();
        }
    }

    function cycleAnimation() {
        const order = ["fire", "matrix", "none"];
        animation = order[(order.indexOf(animation) + 1) % order.length];
    }

    color: bg
    focus: true
    Keys.forwardTo: [passwordBox]

    Behavior on color {
        ColorAnimation {
            duration: 300
        }
    }

    Behavior on smoothLevel {
        NumberAnimation {
            duration: 250
        }
    }

    NumberAnimation on appear {
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.Linear
    }

    Component.onCompleted: passwordBox.forceActiveFocus()

    onBusyChanged: {
        if (!busy)
            passwordBox.forceActiveFocus();
    }

    onLeavingChanged: {
        if (leaving)
            leaveAnim.restart();
    }

    onFailedChanged: {
        if (failed) {
            attempts++;
            spikeAnim.restart();
        }
    }

    NumberAnimation {
        id: leaveAnim
        target: root
        property: "leave"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: spikeAnim
        target: root
        property: "spike"
        from: 20
        to: 0
        duration: 1000
        easing.type: Easing.OutQuad
    }

    Timer {
        id: armTimer
        interval: 2400
        onTriggered: root.armedName = ""
    }

    Timer {
        interval: 530
        repeat: true
        running: !root.leaving
        onTriggered: root.cursorOn = !root.cursorOn
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    TextMetrics {
        id: metrics
        font.family: root.mono
        font.pixelSize: root.fs
        text: "M"
    }

    component Cell: Text {
        property int col: 0
        property int row: 0

        x: col * root.cw
        y: row * root.lh
        color: root.fg
        font.family: root.mono
        font.pixelSize: root.fs
        textFormat: Text.PlainText
    }

    component Hint: Row {
        id: hint

        property string key: ""
        property string label: ""
        property bool armed: false

        signal clicked

        spacing: root.cw

        Text {
            text: hint.key
            color: root.accent
            font.family: root.mono
            font.pixelSize: root.fs
            font.bold: true
        }

        Text {
            text: hint.label
            color: hint.armed ? root.errorColor : Qt.alpha(root.fg, hintArea.containsMouse ? 0.95 : 0.6)
            font.family: root.mono
            font.pixelSize: root.fs
        }

        MouseArea {
            id: hintArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hint.clicked()
        }
    }

    Canvas {
        id: art

        property int cell: 14
        property int cols: 0
        property int rows: 0
        property var fire: null
        property var drops: null
        property var palette: []
        property bool fresh: true
        readonly property string glyphs: "01234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ:.=*+-<>|"

        anchors.fill: parent
        renderTarget: Canvas.Image
        opacity: root.enterBg * (1 - root.exitBg)

        function rgba(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
        }

        function build() {
            const c = root.accent;
            const out = [];
            for (let i = 0; i < 37; i++) {
                const t = i / 36;
                let r, g, b;
                if (t < 0.6) {
                    const k = 0.25 + 0.75 * (t / 0.6);
                    r = c.r * k;
                    g = c.g * k;
                    b = c.b * k;
                } else {
                    const k = ((t - 0.6) / 0.4) * 0.7;
                    r = c.r + (1 - c.r) * k;
                    g = c.g + (1 - c.g) * k;
                    b = c.b + (1 - c.b) * k;
                }
                out.push(i === 0 ? "rgba(0,0,0,0)" : "rgba(" + Math.round(r * 255) + "," + Math.round(g * 255) + "," + Math.round(b * 255) + "," + Math.min(0.9, t * 1.7) + ")");
            }
            palette = out;
        }

        function resize() {
            cell = Math.max(14, Math.ceil(width / 140));
            cols = Math.max(1, Math.ceil(width / cell));
            rows = Math.max(1, Math.ceil(height * 0.55 / cell));
            fire = new Uint8Array(cols * rows);
            const d = [];
            const total = Math.ceil(height / cell);
            for (let i = 0; i < cols; i++)
                d.push(Math.floor(Math.random() * total));
            drops = d;
            fresh = true;
        }

        function step() {
            if (!fire)
                return;
            const lvl = Math.max(0, Math.min(36, Math.round(root.smoothLevel * root.fireScale)));
            const last = (rows - 1) * cols;
            for (let x = 0; x < cols; x++)
                fire[last + x] = Math.max(0, lvl - (Math.random() < 0.3 ? 1 : 0));
            for (let y = 1; y < rows; y++) {
                for (let x = 0; x < cols; x++) {
                    const src = y * cols + x;
                    const v = fire[src];
                    if (v === 0) {
                        fire[src - cols] = 0;
                    } else {
                        const r = Math.round(Math.random() * 3) & 3;
                        const dst = src - r + 1 - cols;
                        if (dst >= 0)
                            fire[dst] = v - (r & 1);
                    }
                }
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            if (root.animation === "fire") {
                ctx.clearRect(0, 0, width, height);
                if (!fire)
                    return;
                const off = height - rows * cell;
                for (let y = 0; y < rows; y++) {
                    for (let x = 0; x < cols; x++) {
                        const v = fire[y * cols + x];
                        if (v > 0) {
                            ctx.fillStyle = palette[v];
                            ctx.fillRect(x * cell, off + y * cell, cell, cell);
                        }
                    }
                }
            } else if (root.animation === "matrix") {
                if (fresh) {
                    ctx.clearRect(0, 0, width, height);
                    fresh = false;
                }
                if (!drops)
                    return;
                ctx.fillStyle = rgba(root.bg, 0.16);
                ctx.fillRect(0, 0, width, height);
                ctx.font = cell + "px " + root.mono;
                ctx.fillStyle = rgba(root.accent, 0.9);
                for (let i = 0; i < cols; i++) {
                    const ch = glyphs.charAt(Math.floor(Math.random() * glyphs.length));
                    ctx.fillText(ch, i * cell, drops[i] * cell);
                    if (drops[i] * cell > height && Math.random() > 0.975)
                        drops[i] = 0;
                    else
                        drops[i]++;
                }
            } else {
                ctx.clearRect(0, 0, width, height);
            }
        }

        onWidthChanged: {
            resize();
            requestPaint();
        }
        onHeightChanged: {
            resize();
            requestPaint();
        }

        Component.onCompleted: {
            build();
            resize();
        }

        Connections {
            target: root

            function onAccentChanged() {
                art.build();
            }

            function onAnimationChanged() {
                art.fresh = true;
                art.requestPaint();
            }
        }

        Timer {
            interval: root.animation === "matrix" ? 70 : 45
            repeat: true
            running: root.animation !== "none" && root.leave < 1
            onTriggered: {
                if (root.animation === "fire")
                    art.step();
                art.requestPaint();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: passwordBox.forceActiveFocus()
    }

    Item {
        id: ui
        anchors.fill: parent

        Row {
            x: root.cw * 2
            y: root.lh - (1 - root.enterBar) * root.lh * 2 - root.exitBar * root.lh * 2
            opacity: root.enterBar * (1 - root.exitBar)
            spacing: root.cw * 3

            Hint {
                key: "F1"
                label: "shutdown"
                armed: root.armedName === "shutdown"
                onClicked: root.power("shutdown", ["systemctl", "poweroff"])
            }

            Hint {
                key: "F2"
                label: "reboot"
                armed: root.armedName === "reboot"
                onClicked: root.power("reboot", ["systemctl", "reboot"])
            }

            Hint {
                key: "F3"
                label: "sleep"
                armed: root.armedName === "sleep"
                onClicked: root.power("sleep", ["systemctl", "suspend"])
            }

            Hint {
                key: "F4"
                label: "anim: " + root.animation
                onClicked: root.cycleAnimation()
            }

            Hint {
                key: "F5"
                label: root.reveal ? "hide" : "show"
                onClicked: root.reveal = !root.reveal
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.cw * 2
            y: root.lh - (1 - root.enterBar) * root.lh * 2 - root.exitBar * root.lh * 2
            opacity: root.enterBar * (1 - root.exitBar)
            text: Qt.locale("en_US").toString(clock.date, "ddd MMM d  HH:mm:ss")
            color: Qt.alpha(root.fg, 0.75)
            font.family: root.mono
            font.pixelSize: root.fs
        }

        Item {
            id: box
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2) - root.lh
            width: root.boxW
            height: root.boxH
            opacity: root.seg(root.appear, 0.15, 0.3) * (1 - root.exitBox)

            transform: Scale {
                origin.x: box.width / 2
                origin.y: box.height / 2
                xScale: Math.max(0.001, (0.3 + 0.7 * root.enterW) * (1 - 0.7 * root.exitW))
                yScale: Math.max(0.001, (0.02 + 0.98 * root.enterH) * (1 - 0.98 * root.exitH))
            }

            Rectangle {
                anchors.fill: parent
                color: root.bg
                opacity: 0.94
            }

            Repeater {
                model: root.boxRows

                Cell {
                    required property int index

                    row: index
                    text: root.frameLine(index)
                    color: root.failed ? root.errorColor : (root.busy || root.leaving ? root.accent : Qt.alpha(root.fg, 0.8))
                }
            }

            Item {
                anchors.fill: parent
                opacity: root.enterText * (1 - root.exitText)

                Cell {
                    col: 3
                    row: 2
                    text: "login:"
                    color: Qt.alpha(root.fg, 0.55)
                }

                Cell {
                    col: root.valueCol
                    row: 2
                    text: root.userName
                }

                Cell {
                    col: 3
                    row: 4
                    text: "password:"
                    color: root.failed ? root.errorColor : root.accent
                    font.bold: true
                }

                Cell {
                    col: root.valueCol
                    row: 4
                    text: root.maskText()
                    color: root.failed ? root.errorColor : root.fg
                }

                Cell {
                    col: root.valueCol + Math.min(root.typed, root.fieldCols - 1)
                    row: 4
                    visible: root.cursorOn && !root.busy && !root.leaving
                    text: "\u2588"
                    color: root.accent
                }

                Cell {
                    col: 3
                    row: 6
                    text: root.statusText()
                    color: root.statusColor()
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -(1 - root.enterBar) * height - root.exitBar * height
            height: Math.round(root.lh * 1.5)
            opacity: root.enterBar * (1 - root.exitBar)
            color: Qt.alpha(root.accent, 0.92)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: root.cw * 2
                anchors.verticalCenter: parent.verticalCenter
                text: root.userName + "@lock"
                color: root.bg
                font.family: root.mono
                font.pixelSize: root.fs
                font.bold: true
            }

            Text {
                anchors.centerIn: parent
                width: parent.width * 0.4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: root.player !== null
                text: root.player ? (root.player.isPlaying ? "\u266a " : "|| ") + root.player.trackTitle + (root.player.trackArtist ? " - " + root.player.trackArtist : "") : ""
                color: root.bg
                font.family: root.mono
                font.pixelSize: root.fs
                textFormat: Text.PlainText
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: root.cw * 2
                anchors.verticalCenter: parent.verticalCenter
                text: "net: " + (root.shell && root.shell.netType !== "" ? (root.shell.netName !== "" ? root.shell.netName : root.shell.netType) : "offline")
                    + (root.hasBat ? "   bat: " + Math.round(root.batFraction * 100) + "%" + (root.charging ? "+" : "") : "")
                    + "   notif: " + root.notifCount
                color: root.bg
                font.family: root.mono
                font.pixelSize: root.fs
                font.bold: true
            }
        }
    }

    TextInput {
        id: passwordBox
        width: 1
        height: 1
        opacity: 0
        focus: true
        enabled: !root.busy
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData

        onTextChanged: root.context.currentText = passwordBox.text
        onAccepted: {
            if (root.typed > 0)
                root.context.tryUnlock();
        }

        Keys.onEscapePressed: passwordBox.text = ""
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F1)
                root.power("shutdown", ["systemctl", "poweroff"]);
            else if (event.key === Qt.Key_F2)
                root.power("reboot", ["systemctl", "reboot"]);
            else if (event.key === Qt.Key_F3)
                root.power("sleep", ["systemctl", "suspend"]);
            else if (event.key === Qt.Key_F4)
                root.cycleAnimation();
            else if (event.key === Qt.Key_F5)
                root.reveal = !root.reveal;
            else
                return;
            event.accepted = true;
        }

        Connections {
            target: root.context

            function onCurrentTextChanged() {
                if (passwordBox.text !== root.context.currentText)
                    passwordBox.text = root.context.currentText;
            }
        }
    }
}
