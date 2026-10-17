import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris

PageBox {
    id: page

    required property var shell

    readonly property var pl: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    readonly property bool round: page.shell.cornerRadius > 0
    readonly property real frac: pl && pl.length > 0 ? Math.max(0, Math.min(1, pl.position / pl.length)) : 0

    name: "music"
    fromY: -22
    pageWidth: 340

    function fmtTime(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0
        const m = Math.floor(sec / 60)
        const s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 1000
        running: page.active && page.pl !== null && page.pl.isPlaying
        repeat: true
        onTriggered: page.pl.positionChanged()
    }

    Text {
        visible: page.pl === null
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 14
        Layout.bottomMargin: 14
        text: "Nothing playing"
        color: page.shell.softText
        font.family: page.shell.textFont
        font.pixelSize: 12
    }

    RowLayout {
        visible: page.pl !== null
        Layout.fillWidth: true
        spacing: 12

        ClippingRectangle {
            Layout.preferredWidth: 76
            Layout.preferredHeight: 76
            Layout.alignment: Qt.AlignTop
            radius: page.round ? (page.pl && page.pl.isPlaying ? 38 : 22) : 0
            color: page.shell.trackColor

            Behavior on radius {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "\uf001"
                color: page.shell.softText
                font.family: page.shell.textFont
                font.pixelSize: 22
            }

            Image {
                id: art
                anchors.fill: parent
                source: page.active && page.pl && page.pl.trackArtUrl ? page.pl.trackArtUrl : ""
                sourceSize.width: 152
                sourceSize.height: 152
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
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
                text: page.pl ? page.pl.trackTitle : ""
                color: page.shell.barFg
                font.family: page.shell.textFont
                font.pixelSize: 13
                font.bold: true
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: page.pl ? page.pl.trackArtist : ""
                color: page.shell.softText
                font.family: page.shell.textFont
                font.pixelSize: 11
                textFormat: Text.PlainText
            }

            RowLayout {
                Layout.topMargin: 4
                spacing: 8

                Pressable {
                    shell: page.shell
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: page.round ? 17 : 0
                    color: Qt.alpha(page.shell.barFg, 0.10)
                    onClicked: {
                        if (page.pl)
                            page.pl.previous()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf048"
                        color: page.shell.barFg
                        font.family: page.shell.textFont
                        font.pixelSize: 12
                    }
                }

                Pressable {
                    shell: page.shell
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    radius: page.round ? (page.pl && page.pl.isPlaying ? 16 : 23) : 0
                    color: page.shell.accentText
                    rippleColor: Qt.alpha(page.shell.barBg, 0.2)
                    onClicked: {
                        if (page.pl)
                            page.pl.togglePlaying()
                    }

                    Behavior on radius {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: page.pl && page.pl.isPlaying ? "\uf04c" : "\uf04b"
                        color: page.shell.barBg
                        font.family: page.shell.textFont
                        font.pixelSize: 16
                    }
                }

                Pressable {
                    shell: page.shell
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: page.round ? 17 : 0
                    color: Qt.alpha(page.shell.barFg, 0.10)
                    onClicked: {
                        if (page.pl)
                            page.pl.next()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf051"
                        color: page.shell.barFg
                        font.family: page.shell.textFont
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    RowLayout {
        visible: page.pl !== null
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.preferredWidth: 30
            text: page.pl ? page.fmtTime(page.pl.position) : ""
            color: page.shell.softText
            font.family: page.shell.textFont
            font.pixelSize: 10
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            radius: page.round ? 3 : 0
            color: page.shell.trackColor

            Rectangle {
                id: fill
                width: Math.max(parent.height, parent.width * page.frac)
                height: parent.height
                radius: parent.radius
                color: page.shell.accentText

                Behavior on width {
                    enabled: !seek.pressed
                    NumberAnimation { duration: 400; easing.type: Easing.Linear }
                }
            }

            Rectangle {
                width: 12
                height: 12
                radius: page.round ? 6 : 0
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                color: page.shell.accentText
                scale: seek.pressed ? 1.35 : (seek.containsMouse ? 1.2 : 1)

                Behavior on scale {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: seek
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                hoverEnabled: true
                preventStealing: true
                onClicked: m => {
                    if (page.pl && page.pl.canSeek && page.pl.length > 0)
                        page.pl.position = Math.max(0, Math.min(1, m.x / width)) * page.pl.length
                }
            }
        }

        Text {
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
            text: page.pl ? page.fmtTime(page.pl.length) : ""
            color: page.shell.softText
            font.family: page.shell.textFont
            font.pixelSize: 10
        }
    }
}
