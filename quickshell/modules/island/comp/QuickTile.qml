import QtQuick
import QtQuick.Layouts

Pressable {
    id: tile

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property bool hasDetail: false

    readonly property color fg: active ? shell.barBg : shell.barFg

    signal detail()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 52
    radius: shell.innerRadius > 0 ? height / 2 : 0
    color: active ? shell.accentText : shell.tileColor
    rippleColor: Qt.alpha(fg, 0.2)

    onHeld: if (hasDetail) detail()
    onSecondary: if (hasDetail) detail()
    onActiveChanged: pop.restart()

    SequentialAnimation {
        id: pop
        NumberAnimation { target: bead; property: "scale"; to: 1.28; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: bead; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: tile.hasDetail ? 6 : 12
        spacing: 8

        Rectangle {
            id: bead
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18
            color: tile.active ? tile.shell.barBg : Qt.alpha(tile.shell.barFg, 0.10)

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? tile.shell.accentText : tile.shell.barFg
                font.family: tile.shell.textFont
                font.pixelSize: 15

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: tile.label
                color: tile.fg
                font.family: tile.shell.textFont
                font.pixelSize: 11
                font.bold: true

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: tile.sub !== ""
                elide: Text.ElideRight
                text: tile.sub
                color: Qt.alpha(tile.fg, 0.7)
                font.family: tile.shell.textFont
                font.pixelSize: 10

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
        }

        Rectangle {
            visible: tile.hasDetail
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 14
            color: Qt.alpha(tile.fg, detailArea.pressed ? 0.22 : 0.10)
            scale: detailArea.pressed ? 0.88 : 1

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf105"
                color: tile.fg
                font.family: tile.shell.textFont
                font.pixelSize: 13
            }

            MouseArea {
                id: detailArea
                anchors.fill: parent
                onClicked: tile.detail()
            }
        }
    }
}
