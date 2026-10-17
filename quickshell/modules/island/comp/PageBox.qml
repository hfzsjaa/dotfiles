import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property string current

    property string name: ""
    property bool suppressed: false
    property real pageWidth: 380
    property real fromX: 0
    property real fromY: 0
    readonly property bool active: current === name && !suppressed
    property real tx: active ? 0 : fromX
    property real ty: active ? 0 : fromY
    property real sc: active ? 1 : 0.9

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 10
    width: pageWidth - 20
    spacing: 8
    opacity: active ? 1 : 0
    visible: opacity > 0.01
    enabled: active
    transform: [
        Translate {
            x: root.tx
            y: root.ty
        },
        Scale {
            origin.x: root.width / 2
            origin.y: 0
            xScale: root.sc
            yScale: root.sc
        }
    ]

    Behavior on tx {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Behavior on ty {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Behavior on sc {
        NumberAnimation {
            duration: root.active ? 360 : 200
            easing.type: root.active ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.9
        }
    }

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.active ? 90 : 0 }
            NumberAnimation { duration: root.active ? 220 : 100 }
        }
    }
}
