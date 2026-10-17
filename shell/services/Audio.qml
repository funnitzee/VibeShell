pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Default sink volume and mute state from wpctl. Polled, so it also picks up
// changes made outside the shell (media keys, pavucontrol). If wpctl is missing
// the values just stay at their defaults and the volume UI hides itself.
Singleton {
    id: root

    property real volume: 0
    property bool muted: false
    readonly property bool available: initialized
    property bool initialized: false

    readonly property int percent: Math.round(volume * 100)

    // Clamp and apply a percentage (0-100). Updates optimistically so the UI and
    // the OSD react immediately; the poll below confirms the real value.
    function setVolume(value) {
        if (!available)
            return;
        const p = Math.max(0, Math.min(100, Math.round(value)));
        root.volume = p / 100;
        if (root.muted && p > 0)
            root.muted = false;
        apply(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (p / 100).toString()]);
    }

    function adjust(delta) {
        if (!available)
            return;
        apply(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${delta}%+`]);
    }

    function toggleMute() {
        if (!available)
            return;
        root.muted = !root.muted;
        apply(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    function apply(command) {
        set.command = command;
        set.running = true;
    }

    Process {
        id: get
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s+([0-9.]+)(\s+\[MUTED\])?/);
                if (!m)
                    return;
                root.volume = Number(m[1]);
                root.muted = Boolean(m[2]);
                // Set last so a startup poll does not pop the OSD.
                root.initialized = true;
            }
        }
    }

    Process {
        id: set
    }

    Timer {
        interval: 750
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!get.running)
                get.running = true;
        }
    }
}
