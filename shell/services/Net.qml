pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

// Active connection for the dashboard: wifi SSID or wired interface, or null
// when nothing is connected. Needs NetworkManager on the system bus.
Singleton {
    id: root

    readonly property var info: {
        const devices = Networking.devices.values;
        const device = devices.find(d => d.connected);
        if (!device)
            return null;
        if (device.type === DeviceType.Wifi) {
            const network = device.networks.values.find(n => n.connected);
            return {
                kind: "wifi",
                name: network ? network.name : device.name
            };
        }
        if (device.type === DeviceType.Wired)
            return {
                kind: "wired",
                name: device.name
            };
        return {
            kind: "net",
            name: device.name
        };
    }
}
