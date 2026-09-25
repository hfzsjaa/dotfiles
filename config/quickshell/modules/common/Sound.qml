import QtQuick
import Quickshell.Io
import Quickshell

Item {
    id: root
    property string notifSound: Quickshell.env("HOME") + "/.config/quickshell/sounds/creatorshome-sharp-pop-328170.mp3"
    property real volume: 1.0

    function play(path) {
        proc.command = ["sh", "-c", `pw-play --volume=${root.volume} '${path}' 2>/dev/null || paplay '${path}' 2>/dev/null`]
        proc.running = true
    }

    function playNotif() { play(notifSound) }


    Process { id: proc }
    Process { id: loopProc }
}
