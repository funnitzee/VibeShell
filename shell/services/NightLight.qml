pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Night light (warmer screen colours) for the :night command and the quick
// settings panel. Uses whichever tool is installed: gammastep or redshift
// (one-shot, best for a toggle) or wlsunset (a small daemon we respawn).
// State lives in Settings (night.enabled / night.temperature), so it sticks
// across reloads and shows up in the settings window.
Singleton {
    id: root

    property string tool: ""

    readonly property bool available: tool !== ""
    readonly property bool oneShot: tool === "gammastep" || tool === "redshift"
    readonly property bool enabled: Settings.data.night.enabled
    readonly property int temperature: Settings.data.night.temperature

    // Warmer colours mean a lower Kelvin value. Handy for the quick settings
    // row and the bar.
    readonly property string label: enabled ? `${temperature}K` : "off"

    function toggle() {
        Settings.set("night.enabled", !root.enabled);
    }

    function set(on) {
        Settings.set("night.enabled", on);
    }

    function setTemperature(kelvin) {
        Settings.set("night.temperature", Math.max(1000, Math.min(6500, Math.round(kelvin))));
    }

    // Move the temperature; step is the number of Kelvin to add (negative for
    // warmer). Clamped to a sane range.
    function adjust(step) {
        setTemperature(root.temperature + step);
    }

    function apply() {
        if (!available)
            return;
        let cmd;
        if (oneShot)
            cmd = root.enabled ? `${tool} -O ${temperature}` : `${tool} -x`;
        else
            cmd = "pkill -x wlsunset 2>/dev/null; " + (root.enabled ? `setsid wlsunset -t ${temperature} -T 6500 >/dev/null 2>&1 &` : "true");
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // Any change coming from the settings window, the palette or the panel ends
    // up here. Setting the same value does not re-emit, so there is no loop.
    onEnabledChanged: apply()
    onTemperatureChanged: {
        if (root.enabled)
            apply();
    }

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "for b in gammastep redshift wlsunset; do command -v $b >/dev/null 2>&1 && { echo $b; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.tool = text.trim();
                if (root.enabled)
                    root.apply();
            }
        }
    }
}
