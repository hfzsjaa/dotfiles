import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Rectangle {
    id: tray

    required property var shell
    required property var host

    readonly property bool recording: shell.recorder.recording
    readonly property bool shown: recording

    width: shown ? row.implicitWidth + 24 : 0
    height: shown ? shell.islandHeight : 0
    radius: shell.cornerRadius
    color: shell.barBg
    border.width: shown ? 1 : 0
    border.color: Qt.alpha(shell.barFg, 0.08)
    opacity: shown ? 1 : 0
    clip: true

    Behavior on width {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    Behavior on color {
        ColorAnimation { duration: 300 }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Item {
            visible: tray.recording
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: recRow.implicitWidth
            implicitHeight: recRow.implicitHeight

            Row {
                id: recRow
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: shell.accent

                    SequentialAnimation on opacity {
                        running: tray.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.recorder.formatted
                    color: shell.barFg
                    font.family: shell.textFont
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: Quickshell.execDetached([
                    "bash",
                    Quickshell.env("HOME") + "/.config/hypr/scripts/record.sh"
                ])
            }
        }

        Rectangle {
            visible: tray.recording && SystemTray.items.values.length > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 1
            Layout.preferredHeight: 12
            color: Qt.alpha(shell.barFg, 0.2)
        }

        Repeater {
            model: SystemTray.items

            Item {
                id: entry
                required property var modelData

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16

                function openMenu() {
                    const p = entry.mapToItem(tray.host.contentItem, 0, 0)
                    menu.anchor.rect = Qt.rect(p.x, p.y, entry.width, entry.height)
                    menu.open()
                }

                Image {
                    anchors.fill: parent
                    source: entry.modelData.icon
                    sourceSize: Qt.size(32, 32)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                QsMenuAnchor {
                    id: menu
                    menu: entry.modelData.menu
                    anchor.window: tray.host
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (mouse.modifiers & Qt.ControlModifier) {
                                if (entry.modelData.hasMenu)
                                    entry.openMenu()
                            } 
                        } else if (mouse.button === Qt.MiddleButton) {
                            entry.modelData.secondaryActivate()
                        } else if (entry.modelData.onlyMenu && entry.modelData.hasMenu) {
                            entry.openMenu()
                        } else {
                            entry.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}