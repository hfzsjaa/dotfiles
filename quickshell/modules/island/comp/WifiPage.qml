import QtQuick
import QtQuick.Layouts
import Quickshell

PageBox {
    id: page

    required property var shell
    required property var wifi

    property string pending: ""
    readonly property bool typing: pending !== ""
    readonly property bool round: shell.innerRadius > 0

    signal back()

    name: "wifi"
    fromX: 30
    pageWidth: 340

    function submit() {
        if (pw.text === "")
            return
        wifi.connect(pending, pw.text, false)
        pending = ""
    }

    function sigBars(s) {
        return s >= 75 ? 4 : (s >= 50 ? 3 : (s >= 25 ? 2 : 1))
    }

    onActiveChanged: {
        pending = ""
        if (active) {
            wifi.refresh()
            wifi.scan()
        }
    }

    onTypingChanged: {
        if (typing) {
            pw.text = ""
            Qt.callLater(() => pw.forceActiveFocus())
        }
    }

    CenterHeader {
        shell: page.shell
        Layout.fillWidth: true
        title: "Wi-Fi"
        checked: page.wifi.enabled
        busy: page.wifi.scanning
        onBack: page.back()
        onToggled: page.wifi.setEnabled(!page.wifi.enabled)
        onAction: page.wifi.scan()
    }

    Text {
        visible: !page.wifi.enabled || page.wifi.networks.length === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        text: !page.wifi.enabled ? "Wi-Fi is off" : (page.wifi.scanning ? "Scanning..." : "No networks found")
        color: page.shell.softText
        font.family: page.shell.textFont
        font.pixelSize: 12
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(188, contentHeight)
        visible: page.active && page.wifi.enabled && count > 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: page.active ? scriptModel : null

        ScriptModel {
            id: scriptModel
            values: page.wifi.networks
        }

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        delegate: ListRow {
            id: item
            required property var modelData

            shell: page.shell
            width: ListView.view.width
            icon: "\uf1eb"
            title: modelData.ssid
            subtitle: page.wifi.busy === modelData.ssid ? "Connecting..." : (modelData.active ? "Connected" : (modelData.saved ? "Saved" : (modelData.secure ? "Secured" : "Open")))
            trailing: modelData.secure ? "\uf023" : ""
            bars: page.sigBars(modelData.signal)
            highlighted: modelData.active
            onClicked: {
                if (modelData.active)
                    page.wifi.disconnect(modelData.ssid)
                else if (modelData.secure && !modelData.saved)
                    page.pending = modelData.ssid
                else
                    page.wifi.connect(modelData.ssid, "", modelData.saved)
            }
            onSecondary: {
                if (modelData.saved)
                    page.wifi.forget(modelData.ssid)
            }
            onHeld: {
                if (modelData.saved)
                    page.wifi.forget(modelData.ssid)
            }
        }
    }

    Rectangle {
        visible: page.typing
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: page.round ? height / 2 : 0
        color: page.shell.tileColor
        border.width: 1
        border.color: pw.activeFocus ? Qt.alpha(page.shell.accentText, 0.6) : "transparent"

        Behavior on border.color {
            ColorAnimation { duration: 160 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 7
            spacing: 8

            Text {
                text: "\uf023"
                color: page.shell.accentText
                font.family: page.shell.textFont
                font.pixelSize: 13
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text === ""
                    text: "Password for " + page.pending
                    elide: Text.ElideRight
                    width: parent.width
                    color: page.shell.softText
                    font.family: page.shell.textFont
                    font.pixelSize: 11
                }

                TextInput {
                    id: pw
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    clip: true
                    color: page.shell.barFg
                    selectionColor: page.shell.accentText
                    selectedTextColor: page.shell.barBg
                    font.family: page.shell.textFont
                    font.pixelSize: 12
                    Keys.onEscapePressed: page.pending = ""
                    Keys.onReturnPressed: page.submit()
                    Keys.onEnterPressed: page.submit()
                }
            }

            Pressable {
                shell: page.shell
                Layout.preferredWidth: 72
                Layout.preferredHeight: 32
                radius: page.round ? 16 : 0
                color: page.shell.accentText
                rippleColor: Qt.alpha(page.shell.barBg, 0.2)
                opacity: pw.text === "" ? 0.45 : 1
                onClicked: page.submit()

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Connect"
                    color: page.shell.barBg
                    font.family: page.shell.textFont
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    Text {
        visible: page.wifi.error !== "" && !page.typing
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: page.wifi.error
        color: page.shell.accent
        font.family: page.shell.textFont
        font.pixelSize: 10
    }
}
