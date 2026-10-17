import QtQuick

Item {
    id: root

    required property var shell

    property bool checked: false

    readonly property bool round: shell.cornerRadius > 0
    readonly property real thumb: area.pressed ? 22 : (checked ? 20 : 14)

    signal toggled()

    implicitWidth: 48
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: root.round ? height / 2 : 0
        color: root.checked ? root.shell.accentText : "transparent"
        border.width: root.checked ? 0 : 2
        border.color: Qt.alpha(root.shell.barFg, 0.45)

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        Behavior on border.width {
            NumberAnimation { duration: 120 }
        }
    }

    Rectangle {
        width: root.thumb
        height: width
        radius: root.round ? width / 2 : 0
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 7 - (width - 14) / 2
        color: root.checked ? root.shell.barBg : Qt.alpha(root.shell.barFg, 0.7)

        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "\uf00c"
            color: root.shell.accentText
            font.family: root.shell.textFont
            font.pixelSize: 10
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: root.toggled()
    }
}