import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Small volume popup at the bottom of the screen, shown for a moment whenever
// the system volume or mute state changes.
Scope {
    PanelWindow {
        id: win

        visible: hideTimer.running
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "vibeshell-osd"

        // Only the bottom edge is anchored, so niri centers it horizontally.
        anchors {
            bottom: true
        }
        margins {
            bottom: Theme.gap * 3
        }

        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        TuiFrame {
            id: frame

            cols: 24
            rows: 3
            title: Audio.muted ? "mute" : "volume"

            Txt {
                anchors.centerIn: parent
                text: {
                    const n = Math.round(Math.max(0, Math.min(100, Audio.percent)) / 100 * 10);
                    return Audio.muted ? "[  muted   ]" : `[${"█".repeat(n)}${"░".repeat(10 - n)}] ${Audio.percent}%`;
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1400
    }

    Connections {
        target: Audio

        // The startup poll fills in the values; do not flash the OSD for it.
        function onVolumeChanged() {
            if (Audio.available)
                hideTimer.restart();
        }
        function onMutedChanged() {
            if (Audio.available)
                hideTimer.restart();
        }
    }
}
