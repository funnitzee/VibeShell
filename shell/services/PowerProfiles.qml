pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// CPU power profiles from power-profiles-daemon (powerprofilesctl), shown in
// the quick settings panel and driven by the :power command. Polled so it also
// reflects changes made elsewhere. Hidden when the tool is not installed.
Singleton {
    id: root

    property bool available: false
    property string active: ""
    property var profiles: []

    // Friendly one-word labels for the quick settings row and the bar.
    function label() {
        if (active === "power-saver")
            return "saver";
        if (active === "performance")
            return "perf";
        return active !== "" ? active : "-";
    }

    function set(name) {
        if (!available || name === "")
            return;
        root.active = name;
        change.command = ["powerprofilesctl", "set", name];
        change.running = true;
    }

    // Cycle through the profiles in order.
    function cycle() {
        if (!available || root.profiles.length === 0)
            return;
        const at = root.profiles.indexOf(root.active);
        root.set(root.profiles[(at + 1) % root.profiles.length]);
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!list.running)
                list.running = true;
        }
    }

    Process {
        id: list
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                let current = "";
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s*(\*)?\s*([a-z][a-z-]*):\s*$/);
                    if (!m)
                        continue;
                    found.push(m[2]);
                    if (m[1])
                        current = m[2];
                }
                root.available = found.length > 0;
                root.profiles = found;
                if (current !== "")
                    root.active = current;
            }
        }
    }

    Process {
        id: change
    }
}
