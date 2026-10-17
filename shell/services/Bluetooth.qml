pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth adapter and known devices for the quick settings panel, straight
// from BlueZ over D-Bus (no bluetoothctl needed). Without an adapter everything
// hides itself.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false

    // Paired, bonded or currently connected devices, connected first.
    readonly property var devices: {
        const a = adapter;
        if (!a)
            return [];
        const list = a.devices.values.filter(d => d.paired || d.bonded || d.connected);
        list.sort((x, y) => (y.connected - x.connected) || (y.battery > x.battery));
        return list;
    }

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }

    function setDiscovering(on) {
        if (adapter)
            adapter.discovering = on;
    }

    function toggleDevice(device) {
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    // Battery as 0..1, tolerating backends that report 0..100.
    function battery(device) {
        if (!device.batteryAvailable)
            return -1;
        const b = device.battery;
        return b <= 1 ? b : b / 100;
    }
}
