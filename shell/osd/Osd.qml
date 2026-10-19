import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Small popup at the bottom of the screen, shown for a moment whenever the
// volume/mute, the night light or the power profile changes. It shows whichever
// changed last (mode).
Scope {
    id: root

    property string mode: "volume"
    // Power profiles are polled; ignore the first reading so startup does not
    // flash the OSD.
    property bool powerReady: false

    function show(m) {
        root.mode = m;
        hideTimer.restart();
    }

    function bar(fraction) {
        const n = Math.round(Math.max(0, Math.min(1, fraction)) * 10);
        return `[${"█".repeat(n)}${"░".repeat(10 - n)}]`;
    }

    readonly property string osdTitle: mode === "brightness" ? "brightness" : mode === "night" ? "night light" : mode === "power" ? "power profile" : (Audio.muted ? "mute" : "volume")

    readonly property string osdBody: {
        if (mode === "brightness")
            return `${bar(Brightness.percent / 100)} ${Brightness.percent}%`;
        if (mode === "night")
            return NightLight.enabled ? `${bar((6500 - NightLight.temperature) / (6500 - 1000))} ${NightLight.temperature}K` : "[   off    ]";
        if (mode === "power")
            return `[ ${PowerProfiles.label()} ]`;
        return Audio.muted ? "[  muted   ]" : `${bar(Audio.percent / 100)} ${Audio.percent}%`;
    }

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
            title: root.osdTitle

            Txt {
                anchors.centerIn: parent
                text: root.osdBody
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
                root.show("volume");
        }
        function onMutedChanged() {
            if (Audio.available)
                root.show("volume");
        }
    }

    Connections {
        target: Brightness

        // update() sets percent before initialized, so the startup read does
        // not flash the OSD.
        function onPercentChanged() {
            if (Brightness.available)
                root.show("brightness");
        }
    }

    Connections {
        target: NightLight

        function onEnabledChanged() {
            if (NightLight.available)
                root.show("night");
        }
        function onTemperatureChanged() {
            if (NightLight.available && NightLight.enabled)
                root.show("night");
        }
    }

    Connections {
        target: PowerProfiles

        function onActiveChanged() {
            if (!root.powerReady) {
                root.powerReady = true;
                return;
            }
            if (PowerProfiles.available)
                root.show("power");
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): int {
            Brightness.adjust(5);
            return Brightness.percent;
        }
        function down(): int {
            Brightness.adjust(-5);
            return Brightness.percent;
        }
        function set(value: int): int {
            Brightness.setPercent(value);
            return Brightness.percent;
        }
    }
}
