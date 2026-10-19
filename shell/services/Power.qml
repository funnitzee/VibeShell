pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Laptop battery from UPower's aggregate device (percentage is 0-1 there).
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device.ready && device.isLaptopBattery
    readonly property int percent: Math.round(device.percentage * 100)
    readonly property bool charging: device.state === UPowerDeviceState.Charging
    readonly property bool full: device.state === UPowerDeviceState.FullyCharged

    readonly property string stateLabel: charging ? "charging" : full ? "full" : "on battery"

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
