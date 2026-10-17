pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

// Network state and control for the dashboard and the quick settings panel.
// Needs NetworkManager on the system bus; without it the lists stay empty.
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

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled

    // Scanned networks, connected and strongest first, empty SSIDs dropped.
    readonly property var wifiNetworks: {
        const device = wifiDevice;
        if (!device)
            return [];
        const list = device.networks.values.filter(n => n.name !== "");
        list.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
        return list;
    }

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    function scan(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }

    function connect(network, psk) {
        if (psk !== undefined && psk !== "")
            network.connectWithPsk(psk);
        else
            network.connect();
    }

    // True when connecting will need a password the shell does not have yet.
    function needsPassword(network) {
        return !network.known && network.security !== WifiSecurityType.Open;
    }

    function disconnect() {
        if (wifiDevice)
            wifiDevice.disconnect();
    }

    // Signal strength as 0..1, tolerating backends that report 0..100.
    function strength(network) {
        const s = network.signalStrength;
        return s <= 1 ? s : s / 100;
    }
}
