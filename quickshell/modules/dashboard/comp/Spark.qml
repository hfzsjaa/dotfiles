import QtQuick
import QtQuick.Layouts

Item {
    id: spark

    required property var shell
    property var values: []
    property real maxValue: 100
    property color barColor: shell.emph(shell.barMain, 1.25)
    readonly property int count: Math.max(1, values.length)
    readonly property real gap: 2

    Layout.fillWidth: true
    Layout.preferredHeight: 28

    Repeater {
        model: spark.values

        Rectangle {
            required property var modelData
            required property int index

            width: Math.max(1, (spark.width - (spark.count - 1) * spark.gap) / spark.count)
            height: Math.max(2, spark.height * Math.min(1, modelData / Math.max(1, spark.maxValue)))
            x: index * (width + spark.gap)
            y: spark.height - height
            radius: spark.shell.cornerRadius > 0 ? 1 : 0
            color: Qt.alpha(spark.barColor, 0.35 + 0.65 * (index / spark.count))
        }
    }
}
