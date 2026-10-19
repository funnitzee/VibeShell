pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs

// Laptop battery from UPower's aggregate device (percentage is 0-1 there).
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device.ready && device.isLaptopBattery
    readonly property int percent: Math.round(device.percentage * 100)
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property bool full: device.state === UPowerDeviceState.FullyCharged

    readonly property string stateLabel: charging ? "charging" : full ? "full" : "on battery"

    // Warn once per discharge when dropping below power.lowThreshold (0 = off).
    property bool _lowWarned: false

    onPercentChanged: root.checkBattery()

    function checkBattery() {
        const th = Settings.data.power.lowThreshold;
        if (!present || th <= 0)
            return;
        if (!charging && !full && percent <= th && !_lowWarned) {
            _lowWarned = true;
            Quickshell.execDetached(["notify-send", "-a", "vibeshell", "-u", "critical", "battery low", `battery at ${percent}%`]);
        } else if (charging || full || percent > th + 3) {
            _lowWarned = false;
        }
    }

    // Session / machine actions for the :power menu. Everything goes through
    // systemd/logind, so no polkit prompt for the usual desktop actions.
    function suspend() {
        // Lock first so the screen is not readable while suspending.
        Quickshell.execDetached(["sh", "-c", "loginctl lock-session; sleep 0.3; systemctl suspend"]);
    }

    function logout() {
        Quickshell.execDetached(["niri", "msg", "action", "quit"]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function shutdown() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
}
