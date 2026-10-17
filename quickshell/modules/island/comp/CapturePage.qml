import QtQuick
import QtQuick.Layouts

PageBox {
    id: page

    required property var shell
    readonly property var capture: shell.capture
    readonly property bool round: shell.innerRadius > 0

    signal done()

    name: "capture"
    fromX: -30
    pageWidth: 340

    component Section: RowLayout {
        id: sec

        property string title

        Layout.fillWidth: true
        Layout.leftMargin: 6
        spacing: 8

        Text {
            text: sec.title.toUpperCase()
            color: page.shell.softText
            font.family: page.shell.textFont
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.alignment: Qt.AlignVCenter
            color: Qt.alpha(page.shell.barFg, 0.08)
        }
    }

    Section {
        title: "Screenshot"
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 6
        columnSpacing: 6

        QuickTile {
            shell: page.shell
            icon: "\uf108"
            label: "Screen"
            onClicked: {
                page.capture.screenshot("screen")
                page.done()
            }
        }

        QuickTile {
            shell: page.shell
            icon: "\uf125"
            label: "Region"
            onClicked: {
                page.capture.screenshot("region")
                page.done()
            }
        }

        QuickTile {
            shell: page.shell
            icon: "\uf2d0"
            label: "Window"
            onClicked: {
                page.capture.screenshot("window")
                page.done()
            }
        }
    }

    Section {
        title: "Record"
    }

    GridLayout {
        visible: !page.capture.recording
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        QuickTile {
            shell: page.shell
            icon: "\uf03d"
            label: "Screen"
            onClicked: {
                page.capture.record("screen")
                page.done()
            }
        }

        QuickTile {
            shell: page.shell
            icon: "\uf125"
            label: "Region"
            onClicked: {
                page.capture.record("region")
                page.done()
            }
        }
    }

    Pressable {
        shell: page.shell
        visible: page.capture.recording
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: page.round ? height / 2 : 0
        color: Qt.alpha(page.shell.accent, 0.2)
        rippleColor: Qt.alpha(page.shell.accent, 0.25)
        onClicked: {
            page.capture.stopRecording()
            page.done()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 8
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: page.shell.accent

                SequentialAnimation on opacity {
                    running: page.capture.recording && page.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Recording  " + page.capture.elapsedText
                color: page.shell.barFg
                font.family: page.shell.textFont
                font.pixelSize: 13
                font.bold: true
            }

            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 36
                radius: page.round ? 18 : 0
                color: page.shell.accent

                Text {
                    anchors.centerIn: parent
                    text: "\uf04d  Stop"
                    color: page.shell.barBg
                    font.family: page.shell.textFont
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
