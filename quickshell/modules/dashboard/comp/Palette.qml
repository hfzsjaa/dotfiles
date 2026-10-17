import QtQuick

QtObject {
    required property var shell

    readonly property color fg: shell.barFg
    readonly property color bg: shell.barBg
    readonly property color accent: shell.emph(shell.barMain, 1.25)
    readonly property color alert: shell.accent
    readonly property color dim: Qt.alpha(shell.barFg, 0.7)
    readonly property color soft: Qt.alpha(shell.barFg, 0.55)
    readonly property color track: Qt.alpha(shell.barFg, 0.14)
    readonly property color tile: Qt.alpha(shell.barFg, 0.07)
    readonly property color line: Qt.alpha(shell.barFg, 0.08)
    readonly property string textFont: shell.textFont
    readonly property int cardRadius: shell.cornerRadius > 0 ? 18 : 0
    readonly property int panelRadius: shell.cornerRadius > 0 ? 24 : 0
}
