pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Screen brightness from brightnessctl (get/max, set <n>%). Polled so the value
// follows changes made elsewhere. If brightnessctl is missing or cannot read the
// backlight, percent stays 0 and the brightness UI hides itself.
Singleton {
    id: root

    property int percent: 0
    property bool initialized: false
    readonly property bool available: initialized

    property int currentValue: 0
    property int maxValue: 0

    function update() {
        if (maxValue <= 0)
            return;
        root.percent = Math.round(currentValue * 100 / maxValue);
        root.initialized = true;
    }

    function setPercent(value) {
        if (!available)
            return;
        const p = Math.max(0, Math.min(100, Math.round(value)));
        root.percent = p;
        set.command = ["brightnessctl", "set", `${p}%`];
        set.running = true;
    }

    function adjust(delta) {
        if (!available)
            return;
        const p = Math.max(1, Math.min(100, root.percent + Math.round(delta)));
        setPercent(p);
    }

    Process {
        id: max
        command: ["brightnessctl", "max"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.maxValue = parseInt(text.trim(), 10) || 0;
                root.update();
            }
        }
    }

    Process {
        id: get
        command: ["brightnessctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentValue = parseInt(text.trim(), 10) || 0;
                root.update();
            }
        }
    }

    Process {
        id: set
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!max.running)
                max.running = true;
            if (!get.running)
                get.running = true;
        }
    }
}
