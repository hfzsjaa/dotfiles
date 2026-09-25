import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: item

    required property var shell
    required property var notif

    property bool popup: false
    property bool leaving: false
    property bool closing: false
    property bool holding: false
    property bool gone: false
    property bool queued: false
    property int tail: 0
    property int urgency: 1
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property string image: ""
    readonly property date time: new Date()
    readonly property bool critical: urgency === 2
    readonly property int duration: {
        if (urgency === 2)
            return shell.urgencyMs[2]
        if (notif && notif.expireTimeout > 0)
            return notif.expireTimeout * 1000
        return shell.urgencyMs[urgency]
    }

    function sync() {
        if (!notif)
            return
        summary = notif.summary
        body = notif.body
        appName = notif.appName
        appIcon = notif.appIcon
        image = notif.image
        urgency = notif.urgency
    }

    function arm() {
        expiry.stop()
        if (popup && duration > 0)
            expiry.start()
    }

    function bump() {
        if (leaving)
            return
        closing = false
        popup = shell.shouldPop(urgency)
        arm()
    }

    function dismiss(delay, extra) {
        if (queued)
            return
        queued = true
        tail = extra || 0
        expiry.stop()
        if (delay > 0) {
            begin.interval = delay
            begin.start()
        } else {
            leave()
        }
    }

    function leave() {
        holding = true
        leaving = true
        closing = true
        popup = false
        settle.restart()
        finish.restart()
    }

    property Timer expiry: Timer {
        interval: item.duration > 0 ? item.duration : 5000
        onTriggered: item.popup = false
    }

    property Timer begin: Timer {
        onTriggered: item.leave()
    }

    property Timer finish: Timer {
        interval: item.shell.leaveMs + item.tail
        onTriggered: {
            item.holding = false
            if (item.gone)
                item.shell.drop(item)
            else if (item.notif)
                item.notif.dismiss()
        }
    }

    property Timer settle: Timer {
        interval: item.shell.dismissMs
        onTriggered: item.closing = false
    }

    property Connections link: Connections {
        target: item.notif
        ignoreUnknownSignals: true

        function onClosed() {
            item.gone = true
            if (!item.holding)
                item.shell.drop(item)
        }

        function onSummaryChanged() {
            item.sync()
            item.bump()
        }

        function onBodyChanged() {
            item.sync()
            item.bump()
        }

        function onUrgencyChanged() {
            item.sync()
            item.bump()
        }

        function onAppIconChanged() {
            item.sync()
        }

        function onImageChanged() {
            item.sync()
        }
    }

    Component.onCompleted: {
        sync()
        arm()
    }
}