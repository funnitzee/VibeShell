pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs

// Notification daemon: quickshell owns org.freedesktop.Notifications and the
// notify/ popup draws whatever arrives as TUI cards. Nothing else on the session
// must claim that bus name (no dunst/mako at the same time).
Singleton {
    id: root

    // All tracked notifications, oldest first.
    readonly property var all: server.trackedNotifications.values

    // What the popup shows: the newest few, newest first.
    readonly property var popup: root.all.slice(-Settings.data.notify.max).reverse()

    // How long a notification lives, in milliseconds. Applications send this in
    // milliseconds; when they send none we use `notify.timeout` (seconds).
    function lifetimeMs(n) {
        return n.expireTimeout > 0 ? n.expireTimeout : Settings.data.notify.timeout * 1000;
    }

    // Critical and resident notifications stay until dismissed.
    function sticky(n) {
        return n.resident || n.urgency === NotificationUrgency.Critical;
    }

    function dismiss(n) {
        n.dismiss();
    }

    function clear() {
        for (const n of root.all)
            n.dismiss();
    }

    NotificationServer {
        id: server

        // Keep notifications across a shell reload.
        keepOnReload: true

        // We draw plain text only, but support actions and images being sent.
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false
        persistenceSupported: false

        onNotification: notification => {
            notification.tracked = true;
        }
    }
}
