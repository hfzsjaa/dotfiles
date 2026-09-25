import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var shell
    required property var modelData

    readonly property bool focused: {
        const m = Hyprland.focusedMonitor
        return !m || m.name === modelData.name
    }
    readonly property var popups: shell.notifs.filter(n => n.popup).slice(0, 4)

    screen: modelData
    anchors.top: true
    margins.top: shell.topMargin + shell.islandHeight + 8
    implicitWidth: 340
    implicitHeight: 600
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: list.count > 0 && !shell.ccOpen
    mask: Region { item: list }

    WlrLayershell.namespace: "island-notif"
    WlrLayershell.layer: WlrLayer.Overlay

    ListView {
        id: list
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: contentHeight
        interactive: false
        spacing: 8
        model: ScriptModel { values: win.focused ? win.popups : [] }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
        }

        delegate: NotifCard {
            required property var modelData

            width: list.width
            shell: win.shell
            entry: modelData
            floating: true
        }
    }
}