import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../notifications"
import qs.modules.dashboard.comp

ShadePanel {
    id: win

    tag: "island-notifications"
    panelWidth: 460
    open: shell.notifOpen
    siblings: ["dashboardOpen"]
    onDismissed: shell.notifOpen = false

    readonly property var player: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    function greeting() {
        const h = clk.date.getHours()
        const name = Quickshell.env("USER")
        const g = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return name ? g + ", " + name : g
    }

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0
        const m = Math.floor(sec / 60)
        const s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    component B: Block {
        reveal: win.reveal
    }

    component P: Pressable {
        pal: win.pal
    }

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 1000
        running: win.open && win.player !== null && win.player.isPlaying
        repeat: true
        onTriggered: win.player.positionChanged()
    }

    B {
        order: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: win.greeting()
                    color: win.pal.dim
                    font.family: win.pal.textFont
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(clk.date, "HH:mm")
                    color: win.pal.accent
                    font.family: win.shell.clockFont
                    font.pixelSize: 64
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 10
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Qt.formatDateTime(clk.date, "dddd, d MMMM")
                    color: win.pal.soft
                    font.family: win.pal.textFont
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            P {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: win.pal.cardRadius > 0 ? 22 : 0
                color: win.pal.tile
                onClicked: {
                    win.shell.notifOpen = false
                    win.shell.dashboardOpen = true
                }

                Text {
                    anchors.centerIn: parent
                    text: "\uf013"
                    color: win.pal.fg
                    font.family: win.pal.textFont
                    font.pixelSize: 16
                }
            }
        }
    }

    B {
        order: 1
        visible: win.player !== null

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: mcol.implicitHeight + 24
            radius: win.pal.cardRadius
            color: win.pal.tile

            ColumnLayout {
                id: mcol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ClippingRectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        radius: win.shell.cornerRadius > 0 ? 12 : 0
                        color: win.pal.track

                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "\uf001"
                            color: win.pal.soft
                            font.family: win.pal.textFont
                            font.pixelSize: 18
                        }

                        Image {
                            id: art
                            anchors.fill: parent
                            source: win.player && win.player.trackArtUrl ? win.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: win.player ? win.player.trackTitle : ""
                            color: win.pal.fg
                            font.family: win.pal.textFont
                            font.pixelSize: 13
                            font.bold: true
                            textFormat: Text.PlainText
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: win.player ? win.player.trackArtist : ""
                            color: win.pal.soft
                            font.family: win.pal.textFont
                            font.pixelSize: 11
                            textFormat: Text.PlainText
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: win.player ? win.fmtTime(win.player.position) : ""
                        color: win.pal.soft
                        font.family: win.pal.textFont
                        font.pixelSize: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        Layout.alignment: Qt.AlignVCenter
                        radius: 2
                        color: win.pal.track

                        Rectangle {
                            width: parent.width * (win.player && win.player.length > 0 ? Math.min(1, win.player.position / win.player.length) : 0)
                            height: parent.height
                            radius: parent.radius
                            color: win.pal.accent
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -8
                            anchors.bottomMargin: -8
                            onClicked: m => {
                                if (win.player && win.player.canSeek && win.player.length > 0)
                                    win.player.position = Math.max(0, Math.min(1, m.x / width)) * win.player.length
                            }
                        }
                    }

                    Text {
                        text: win.player ? win.fmtTime(win.player.length) : ""
                        color: win.pal.soft
                        font.family: win.pal.textFont
                        font.pixelSize: 10
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    P {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: "transparent"
                        onClicked: {
                            if (win.player)
                                win.player.previous()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf048"
                            color: win.pal.fg
                            font.family: win.pal.textFont
                            font.pixelSize: 14
                        }
                    }

                    P {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: win.player && win.player.isPlaying ? 16 : 23
                        color: win.pal.accent
                        rippleColor: Qt.alpha(win.pal.bg, 0.2)
                        onClicked: {
                            if (win.player)
                                win.player.togglePlaying()
                        }

                        Behavior on radius {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: win.player && win.player.isPlaying ? "\uf04c" : "\uf04b"
                            color: win.pal.bg
                            font.family: win.pal.textFont
                            font.pixelSize: 16
                        }
                    }

                    P {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: "transparent"
                        onClicked: {
                            if (win.player)
                                win.player.next()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf051"
                            color: win.pal.fg
                            font.family: win.pal.textFont
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }

    B {
        order: 2

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Notifications"
                color: win.pal.dim
                font.family: win.pal.textFont
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                visible: win.shell.notifs.length > 0
                text: "Clear all"
                color: win.pal.accent
                font.family: win.pal.textFont
                font.pixelSize: 11
                font.bold: true

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: win.shell.clearAll()
                }
            }
        }

        Text {
            visible: win.shell.notifs.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            text: "No notifications"
            color: win.pal.soft
            font.family: win.pal.textFont
            font.pixelSize: 12
        }

        ListView {
            id: nlist
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(420, contentHeight)
            visible: count > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: win.shell.sorted }

            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 240
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                }
            }

            delegate: Item {
                id: row
                required property var modelData
                readonly property bool leaving: modelData ? modelData.leaving : false

                width: nlist.width
                height: card.implicitHeight

                NotifCard {
                    id: card
                    width: parent.width
                    shell: win.shell
                    entry: row.modelData
                    opacity: row.leaving ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: win.shell.leaveMs
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}
