import Quickshell.Services.Notifications
import QtQuick
import qs
import qs.components
import qs.services

// One notification drawn as a TUI card: the app name sits in the frame title, the
// summary and body fill the inner rows, and any actions become clickable
// shortcuts on the last row. Clicking the card (or its timer running out)
// dismisses it.
TuiFrame {
    id: root

    required property var notification

    readonly property var n: notification
    readonly property color tint: n.urgency === NotificationUrgency.Critical ? Theme.urgent : n.urgency === NotificationUrgency.Low ? Theme.dim : Theme.accent

    readonly property var bodyList: {
        if (!n.body)
            return [];
        return n.body.replace(/\s+$/, "").split("\n").slice(0, 3);
    }
    readonly property int actionRows: n.actions.length > 0 ? 1 : 0

    cols: 44
    rows: 2 + 1 + bodyList.length + actionRows
    title: n.appName || "notification"
    color: Theme.dim

    // Dismiss on click; sits below the action shortcuts so those win.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifications.dismiss(root.n)
    }

    Txt {
        width: parent.width
        elide: Text.ElideRight
        color: root.tint
        text: root.n.summary
    }

    Repeater {
        model: root.bodyList

        delegate: Txt {
            required property string modelData
            required property int index
            y: (1 + index) * Theme.cellH
            width: parent.width
            elide: Text.ElideRight
            color: Theme.fg
            text: modelData
        }
    }

    Row {
        y: (1 + root.bodyList.length) * Theme.cellH
        spacing: Theme.cellW * 3

        Repeater {
            model: root.actionRows > 0 ? root.n.actions : []

            delegate: Txt {
                required property var modelData
                text: `[ ${modelData.text} ]`
                color: Theme.accent

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.invoke()
                }
            }
        }
    }

    Timer {
        interval: Math.round(Notifications.lifetimeMs(root.n))
        running: !Notifications.sticky(root.n)
        onTriggered: Notifications.dismiss(root.n)
    }
}
