import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: cal

    required property var shell
    property date now: new Date()
    property int weekStart: 1
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    readonly property var cells: build(viewYear, viewMonth, now)

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 8

    function shift(d) {
        const n = new Date(viewYear, viewMonth + d, 1)
        viewYear = n.getFullYear()
        viewMonth = n.getMonth()
    }

    function reset() {
        const n = new Date()
        viewYear = n.getFullYear()
        viewMonth = n.getMonth()
    }

    function build(year, month, today) {
        const out = []
        for (let i = 0; i < 7; i++)
            out.push({ head: true, label: dayNames[(weekStart + i) % 7], inMonth: true, today: false })

        const first = new Date(year, month, 1)
        const offset = (first.getDay() - weekStart + 7) % 7
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i)
            out.push({
                head: false,
                label: String(d.getDate()),
                inMonth: d.getMonth() === month,
                today: d.getFullYear() === today.getFullYear()
                    && d.getMonth() === today.getMonth()
                    && d.getDate() === today.getDate()
            })
        }
        return out
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: Qt.formatDateTime(new Date(cal.viewYear, cal.viewMonth, 1), "MMMM yyyy")
            color: cal.shell.barFg
            font.family: cal.shell.textFont
            font.pixelSize: 14
            font.bold: true

            MouseArea {
                anchors.fill: parent
                onClicked: cal.reset()
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "\uf053"
            color: Qt.alpha(cal.shell.barFg, 0.6)
            font.family: cal.shell.textFont
            font.pixelSize: 12

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: cal.shift(-1)
            }
        }

        Item { Layout.preferredWidth: 6 }

        Text {
            text: "\uf054"
            color: Qt.alpha(cal.shell.barFg, 0.6)
            font.family: cal.shell.textFont
            font.pixelSize: 12

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: cal.shift(1)
            }
        }
    }

    Item {
        id: holder
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 7 * 24
        Layout.preferredHeight: 7 * 30

        Grid {
            id: grid
            width: holder.width
            height: holder.height
            columns: 7

            Repeater {
                model: cal.cells

                Item {
                    id: cell
                    required property var modelData

                    width: grid.width / 7
                    height: grid.height / 7

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.9
                        height: width
                        radius: cal.shell.cornerRadius > 0 ? 8 : 0
                        color: cell.modelData.today ? cal.accentText : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.label
                        color: cell.modelData.today
                            ? cal.shell.barBg
                            : cell.modelData.head
                                ? Qt.alpha(cal.shell.barFg, 0.6)
                                : cell.modelData.inMonth ? cal.shell.barFg : Qt.alpha(cal.shell.barFg, 0.3)
                        font.family: cal.shell.textFont
                        font.pixelSize: cell.modelData.head ? 11 : 12
                        font.bold: cell.modelData.head || cell.modelData.today
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => cal.shift(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }
}
