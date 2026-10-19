pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs

// Notification daemon and popup backing store. Nothing else on the session must
// claim the org.freedesktop.notifications bus name (no dunst/mako at once).
// Supports Do Not Disturb (notify.dnd) and keeps a rolling history that the
// `:notify` command can browse.
Singleton {
    id: root

    // Do Not Disturb: suppress popups but still record history.
    readonly property bool dnd: Settings.data.notify.dnd

    // Snapshot of everything received, newest last, capped by notify.historyMax.
    property var _history: []
    readonly property var history: _history

    // All currently tracked notifications, oldest first.
    readonly property var all: server.trackedNotifications.values

    // What the popup shows: the newest few, newest first. Nothing while DND.
    readonly property var popup: root.dnd ? [] : root.all.slice(-Settings.data.notify.max).reverse()

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

    function clearHistory() {
        root._history = [];
    }

    function record(n) {
        root._history = root._history.concat([{
            summary: n.summary,
            body: n.body,
            app: n.appName,
            urgency: n.urgency,
            time: Date.now()
        }]).slice(-Settings.data.notify.historyMax);
    }

    function toggleDnd() {
        Settings.set("notify.dnd", !root.dnd);
    }

    function setDnd(on) {
        Settings.set("notify.dnd", on);
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
            root.record(notification);
            if (root.dnd) {
                // Drop it right away so nothing piles up behind the scenes; the
                // history snapshot above is what survives.
                notification.tracked = true;
                notification.dismiss();
                return;
            }
            notification.tracked = true;
        }
    }
}
