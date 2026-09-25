import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var shell
    spacing: 8

    Flow {
        Layout.fillWidth: true
        spacing: 10

        Repeater {
            model: root.shell.themeNames

            Rectangle {
                id: swatch
                required property string modelData
                readonly property bool active: root.shell.themeMode === modelData
                readonly property var preset: modelData === "pywal" ? null : root.shell.themePresets[modelData]
                readonly property color swBg: modelData === "pywal" ? root.shell.pywalBg : preset.bg
                readonly property color swMain: modelData === "pywal" ? root.shell.pywalMain : preset.main

                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: swBg
                border.width: active ? 2 : 1
                border.color: active ? root.shell.emph(swMain, 1.4) : Qt.alpha(root.shell.barFg, 0.15)

                Behavior on border.width { NumberAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: swatch.swMain
                }

                MouseArea {
                    id: swArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.shell.setTheme(swatch.modelData)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.shell.barFg
                    opacity: swArea.containsMouse && !swatch.active ? 0.1 : 0

                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.shell.themeMode === "pywal" ? "Pywal (dynamic)" : root.shell.themeMode
        color: Qt.alpha(root.shell.barFg, 0.6)
        font.family: root.shell.textFont
        font.pixelSize: 11
        font.bold: true
        elide: Text.ElideRight
    }
}
