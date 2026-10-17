pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Workspace state from niri. Listens to the event stream and re-queries
// `niri msg workspaces` whenever a workspace event arrives.
Singleton {
    id: root

    property var workspaces: []
    property string windowTitle: ""

    function focusWorkspace(idx) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    function refreshWindowTitle() {
        if (!focusedQuery.running)
            focusedQuery.running = true;
    }

    property bool _pending: false

    function refresh() {
        if (query.running)
            _pending = true;
        else
            query.running = true;
    }

    Process {
        id: events
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("{\"Workspace"))
                    root.refresh();
                else if (data.includes("WindowFocusChanged"))
                    root.refreshWindowTitle();
            }
        }
        // niri restarted or not running yet: try again shortly.
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: events.running = true
    }

    Process {
        id: query
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text).sort((a, b) => a.idx - b.idx);
                } catch (e) {
                    console.warn("VibeShell: could not parse niri workspaces:", e);
                }
            }
        }
        onExited: {
            if (root._pending) {
                root._pending = false;
                running = true;
            }
        }
    }

    Process {
        id: focusedQuery
        command: ["niri", "msg", "--json", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    root.windowTitle = w && w.title ? w.title : "";
                } catch (e) {
                    root.windowTitle = "";
                }
            }
        }
    }
}
