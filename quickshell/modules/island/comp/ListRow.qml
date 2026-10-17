import QtQuick
import QtQuick.Layouts

Pressable {
    id: row

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property int bars: -1
    property bool highlighted: false

    readonly property color fg: highlighted ? shell.barBg : shell.barFg
    readonly property bool round: shell.innerRadius > 0

    height: 50
    radius: round ? height / 2 : 0
    color: highlighted ? shell.accentText : shell.tileColor
    rippleColor: Qt.alpha(fg, 0.2)

    onHighlightedChanged: pop.restart()

    SequentialAnimation {
        id: pop
        NumberAnimation { target: bead; property: "scale"; to: 1.28; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: bead; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 14
        spacing: 10

        Rectangle {
            id: bead
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: round ? 17 : 0
            color: row.highlighted ? row.shell.barBg : Qt.alpha(row.shell.barFg, 0.10)

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            Text {
                anchors.centerIn: parent
                text: row.icon
                color: row.highlighted ? row.shell.accentText : row.shell.barFg
                font.family: row.shell.textFont
                font.pixelSize: 14

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
                text: row.title
                color: row.fg
                font.family: row.shell.textFont
                font.pixelSize: 12
                font.bold: true
                textFormat: Text.PlainText

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                elide: Text.ElideRight
                text: row.subtitle
                color: Qt.alpha(row.fg, 0.7)
                font.family: row.shell.textFont
                font.pixelSize: 10

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
        }

        Row {
            visible: row.bars >= 0
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    width: 3
                    height: 5 + index * 3
                    anchors.bottom: parent.bottom
                    radius: 1.5
                    color: Qt.alpha(row.fg, index < row.bars ? 0.95 : 0.25)

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }
            }
        }

        Text {
            visible: row.trailing !== ""
            text: row.trailing
            color: Qt.alpha(row.fg, 0.8)
            font.family: row.shell.textFont
            font.pixelSize: 11

            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }
    }
}
