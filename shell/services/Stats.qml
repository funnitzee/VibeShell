pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// CPU and memory usage, polled from /proc.
Singleton {
    id: root

    property int cpu: 0
    property int mem: 0

    property real _lastTotal: 0
    property real _lastIdle: 0

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            // First line: "cpu user nice system idle iowait irq softirq steal ..."
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            const dt = total - root._lastTotal;
            if (root._lastTotal > 0 && dt > 0)
                root.cpu = Math.round(100 * (1 - (idle - root._lastIdle) / dt));
            root._lastTotal = total;
            root._lastIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const total = Number(t.match(/MemTotal:\s+(\d+)/)[1]);
            const avail = Number(t.match(/MemAvailable:\s+(\d+)/)[1]);
            root.mem = Math.round(100 * (1 - avail / total));
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
        }
    }
}
