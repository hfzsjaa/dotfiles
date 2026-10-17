import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: card

    required property var shell
    required property var entry
    property bool popup: false
    property int more: 0

    readonly property int pad: popup ? 14 : 12
    readonly property bool round: shell.cornerRadius > 0
    readonly property var notif: entry ? entry.notif : null
    readonly property int urgency: entry ? entry.urgency : 1
    readonly property bool critical: urgency === 2
    readonly property string appName: entry ? entry.appName : ""
    readonly property string summary: entry ? entry.summary : ""
    readonly property string bodyText: entry ? entry.body : ""
    readonly property date time: entry ? entry.time : new Date()
    readonly property color accentText: shell.emph(shell.barMain, 1.25)
    readonly property color dim: Qt.alpha(shell.barFg, 0.7)
    readonly property color soft: Qt.alpha(shell.barFg, 0.6)
    readonly property color chip: Qt.alpha(shell.barFg, 0.1)
    readonly property color levelColor: urgency === 2 ? shell.accent : urgency === 0 ? Qt.alpha(shell.barFg, 0.5) : accentText

    readonly property string iconSource: {
        if (!entry)
            return ""
        if (entry.image !== "")
            return entry.image
        if (entry.appIcon === "")
            return ""
        if (entry.appIcon.startsWith("/"))
            return "file://" + entry.appIcon
        if (entry.appIcon.startsWith("file:"))
            return entry.appIcon
        return Quickshell.iconPath(entry.appIcon, true)
    }

    readonly property var actionList: {
        const out = []
        if (notif) {
            const a = notif.actions
            for (let i = 0; i < a.length; i++) {
                if (a[i].identifier !== "default")
                    out.push(a[i])
            }
        }
        return out
    }

    function invokeDefault() {
        if (!notif)
            return
        const a = notif.actions
        for (let i = 0; i < a.length; i++) {
            if (a[i].identifier === "default") {
                a[i].invoke()
                return
            }
        }
    }

    function dismiss() {
        if (entry)
            entry.dismiss(0)
    }

    implicitHeight: layout.implicitHeight + pad * 2
    radius: popup ? 0 : (round ? 22 : 0)
    color: popup ? "transparent" : Qt.alpha(shell.barFg, 0.08)
    border.width: !popup && critical ? 1 : 0
    border.color: shell.accent

    HoverHandler {
        enabled: card.popup
        onHoveredChanged: {
            if (!card.entry)
                return
            if (hovered)
                card.entry.expiry.stop()
            else
                card.entry.arm()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                card.invokeDefault()
            card.dismiss()
        }
    }

    ColumnLayout {
        id: layout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: card.pad
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                radius: card.round ? 20 : 0
                color: Qt.alpha(card.levelColor, 0.16)

                Text {
                    anchors.centerIn: parent
                    visible: icon.status !== Image.Ready
                    text: card.critical ? "\uf071" : "\uf0f3"
                    color: card.levelColor
                    font.family: shell.textFont
                    font.pixelSize: 16
                }

                Image {
                    id: icon
                    anchors.fill: parent
                    anchors.margins: 7
                    source: card.iconSource
                    sourceSize: Qt.size(80, 80)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: card.appName
                        color: card.soft
                        font.family: shell.textFont
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Rectangle {
                        visible: card.urgency !== 1
                        implicitWidth: levelText.implicitWidth + 12
                        implicitHeight: 16
                        radius: card.round ? 8 : 0
                        color: Qt.alpha(card.levelColor, 0.18)

                        Text {
                            id: levelText
                            anchors.centerIn: parent
                            text: card.critical ? "critical" : "low"
                            color: card.levelColor
                            font.family: shell.textFont
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Text {
                        text: (card.more > 0 ? "+" + card.more + "  " : "") + Qt.formatDateTime(card.time, "HH:mm")
                        color: card.soft
                        font.family: shell.textFont
                        font.pixelSize: 10
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.summary
                    color: card.urgency === 0 ? card.dim : shell.barFg
                    font.family: shell.textFont
                    font.pixelSize: 13
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.bodyText
                    color: card.dim
                    font.family: shell.textFont
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: card.popup ? 3 : 4
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                }
            }

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignTop
                radius: card.round ? 13 : 0
                color: Qt.alpha(shell.barFg, closeArea.pressed ? 0.20 : 0.10)

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    color: card.soft
                    font.family: shell.textFont
                    font.pixelSize: 11
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    onClicked: card.dismiss()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: card.actionList.length > 0

            Repeater {
                model: card.actionList

                Rectangle {
                    id: abtn
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 30
                    radius: card.round ? height / 2 : 0
                    color: Qt.alpha(card.accentText, aArea.pressed ? 0.30 : 0.16)
                    scale: aArea.pressed ? 0.96 : 1

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: abtn.modelData.text
                        color: card.accentText
                        font.family: shell.textFont
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: aArea
                        anchors.fill: parent
                        onClicked: {
                            abtn.modelData.invoke()
                            card.dismiss()
                        }
                    }
                }
            }
        }
    }
}