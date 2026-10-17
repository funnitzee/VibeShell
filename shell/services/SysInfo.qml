pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Slow-changing system info for the dashboard: uptime, load average, disk usage.
// Only polled while the dashboard is open.
Singleton {
    id: root

    property real uptime: 0
    property string load: ""
    property int disk: 0

    function formatUptime(seconds) {
        const m = Math.floor(seconds / 60) % 60;
        const h = Math.floor(seconds / 3600) % 24;
        const d = Math.floor(seconds / 86400);
        return d > 0 ? `${d}d ${h}h ${m}m` : `${h}h ${m}m`;
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0])
    }

    FileView {
        id: loadFile
        path: "/proc/loadavg"
        onLoaded: root.load = text().split(" ").slice(0, 3).join(" ")
    }

    Process {
        id: df
        command: ["df", "-P", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[1] ?? "";
                const pct = parseInt(line.split(/\s+/)[4]);
                if (!isNaN(pct))
                    root.disk = pct;
            }
        }
    }

    Timer {
        interval: 5000
        running: Ui.dashboardOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            uptimeFile.reload();
            loadFile.reload();
            if (!df.running)
                df.running = true;
        }
    }
}
