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

    // Run any niri action with optional arguments (used by :niri and :tile).
    // Ipc niri rejects unknown actions on stderr with a non-zero exit code, so
    // surface that as a notification instead of failing silently.
    function action(name, args) {
        actionProc.label = name;
        actionProc.command = ["niri", "msg", "action", name].concat((args ?? []).map(String));
        actionProc.running = true;
    }

    Process {
        id: actionProc
        property string label: ""
        stderr: StdioCollector {
            id: actionErr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                return;
            const msg = actionErr.text.trim() || `unknown action: ${actionProc.label}`;
            console.warn("VibeShell: niri action failed:", msg);
            Quickshell.execDetached(["notify-send", "-a", "vibeshell", "-u", "low", "niri", msg]);
        }
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
