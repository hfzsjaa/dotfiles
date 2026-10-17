pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var shell: null

    readonly property color fg: shell ? shell.barFg : "#ffffff"
    readonly property color bg: shell ? shell.barBg : "#000000"
    readonly property color main: shell ? shell.barMain : "#b48ead"
    readonly property color danger: shell ? shell.accent : "#bf616a"
    readonly property color accentOn: shell ? shell.emph(shell.barMain, 1.25) : "#c9a6c4"
    readonly property string font: shell ? shell.textFont : "Hack Nerd Font"
    readonly property string clockFont: shell ? shell.clockFont : "Ndot55"

    readonly property color primary: accentOn
    readonly property color onPrimary: bg
    readonly property color surface: Qt.alpha(fg, 0.08)
    readonly property color surfaceHigh: Qt.alpha(fg, 0.14)
    readonly property color track: Qt.alpha(fg, 0.15)
    readonly property color outline: Qt.alpha(fg, 0.1)
    readonly property color dim: Qt.alpha(fg, 0.55)
}
