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
}
