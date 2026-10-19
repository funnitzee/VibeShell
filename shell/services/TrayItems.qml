pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// The StatusNotifier items, exposed both to the bar (which renders them) and to
// scripts. Everything lives on one object so a single IPC handler owns the
// "tray" target even though the bar is created once per screen.
Singleton {
    id: root

    readonly property var items: SystemTray.items.values

    IpcHandler {
        target: "tray"

        function count(): int {
            return root.items.length;
        }

        function title(i: int): string {
            return i >= 0 && i < root.items.length ? root.items[i].title : "";
        }

        function activate(i: int): void {
            if (i >= 0 && i < root.items.length)
                root.items[i].activate();
        }

        function secondary(i: int): void {
            if (i >= 0 && i < root.items.length)
                root.items[i].secondaryActivate();
        }

        function scroll(i: int, delta: int): void {
            if (i >= 0 && i < root.items.length)
                root.items[i].scroll(delta, false);
        }
    }
}
