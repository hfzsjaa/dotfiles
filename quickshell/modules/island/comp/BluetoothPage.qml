import QtQuick
import QtQuick.Layouts
import Quickshell

PageBox {
    id: page

    required property var shell
    required property var bt

    signal back()

    name: "bluetooth"
    fromX: 30
    pageWidth: 340

    onActiveChanged: {
        if (active) {
            bt.refresh()
            bt.scan()
        }
    }

    CenterHeader {
        shell: page.shell
        Layout.fillWidth: true
        title: "Bluetooth"
        checked: page.bt.power
        busy: page.bt.scanning
        onBack: page.back()
        onToggled: page.bt.setPower(!page.bt.power)
        onAction: page.bt.scan()
    }

    Text {
        visible: !page.bt.power || page.bt.devices.length === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        text: !page.bt.power ? "Bluetooth is off" : (page.bt.scanning ? "Searching..." : "No devices found")
        color: page.shell.softText
        font.family: page.shell.textFont
        font.pixelSize: 12
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(188, contentHeight)
        visible: page.active && page.bt.power && count > 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: page.active ? scriptModel : null

        ScriptModel {
            id: scriptModel
            values: page.bt.devices
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
            icon: "\uf293"
            title: modelData.name
            subtitle: page.bt.busy === modelData.mac
                ? "Connecting..."
                : (modelData.connected
                    ? "Connected" + (modelData.battery >= 0 ? "  \u00b7  " + modelData.battery + "%" : "")
                    : (modelData.paired ? "Paired" : "Available"))
            trailing: modelData.connected ? "\uf00c" : ""
            highlighted: modelData.connected
            onClicked: {
                if (modelData.connected)
                    page.bt.disconnect(modelData.mac)
                else if (modelData.paired)
                    page.bt.connect(modelData.mac)
                else
                    page.bt.pair(modelData.mac)
            }
            onSecondary: {
                if (modelData.paired)
                    page.bt.remove(modelData.mac)
            }
            onHeld: {
                if (modelData.paired)
                    page.bt.remove(modelData.mac)
            }
        }
    }
}