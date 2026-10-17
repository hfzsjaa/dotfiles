pragma Singleton

import Quickshell

Singleton {
    readonly property var emphasized: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var bounce: [0.34, 1.28, 0.64, 1, 1, 1]
    readonly property var accelerate: [0.4, 0, 1, 0.6, 1, 1]

    readonly property int instant: 90
    readonly property int fast: 160
    readonly property int base: 260
    readonly property int slow: 440

    readonly property real widthSpring: 2.8
    readonly property real widthDamping: 0.54
    readonly property real heightSpring: 3.2
    readonly property real heightDamping: 0.58
    readonly property real closeSpring: 3.6
    readonly property real closeDamping: 0.84
}
