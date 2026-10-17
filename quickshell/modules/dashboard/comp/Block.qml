import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property int order: 0
    property real reveal: 0
    readonly property real a: {
        const t = Math.max(0, Math.min(1, (reveal - 0.45 - order * 0.05) / 0.3))
        return t * t * (3 - 2 * t)
    }

    Layout.fillWidth: true
    spacing: 8
    opacity: a
    transform: Translate {
        y: (1 - a) * 16
    }
}
