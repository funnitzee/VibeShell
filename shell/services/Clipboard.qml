pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history for the :clip command, backed by cliphist + wl-clipboard.
// A `wl-paste --watch cliphist store` watcher is started once so the history
// fills up on its own; if one is already running (e.g. from niri's config) it
// is left alone. Entries are newest first, as `cliphist list` returns them.
Singleton {
    id: root

    property bool available: false
    property var entries: []

    function refresh() {
        if (available && !list.running)
            list.running = true;
    }

    function copy(id) {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${JSON.stringify(String(id))} | wl-copy`]);
        refresh();
    }

    function clear() {
        Quickshell.execDetached(["sh", "-c", "cliphist wipe"]);
        root.entries = [];
    }

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1 && echo ok"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "ok";
                if (root.available) {
                    root.refresh();
                    watcher.running = true;
                }
            }
        }
    }

    // Store every new selection. Skipped when another watcher already exists,
    // so a shell reload never stacks a second one.
    Process {
        id: watcher
        running: false
        command: ["sh", "-c", "! pgrep -x wl-paste >/dev/null 2>&1 && exec wl-paste --watch cliphist store"]
    }

    Process {
        id: list
        running: false
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l !== "").map(l => {
                    const i = l.indexOf("\t");
                    return i >= 0 ? {
                        id: l.slice(0, i),
                        preview: l.slice(i + 1)
                    } : {
                        id: l,
                        preview: l
                    };
                });
                root.entries = rows;
            }
        }
    }
}
