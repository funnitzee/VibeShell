pragma Singleton

import Quickshell

// Shared open/closed state of popups, so the bar can open what other files draw.
// Only one of them is open at a time.
Singleton {
    property bool dashboardOpen: false
    property bool quickOpen: false
    property bool settingsOpen: false
    property bool keysOpen: false

    function closeAll() {
        dashboardOpen = false;
        quickOpen = false;
        settingsOpen = false;
        keysOpen = false;
    }

    function open() {
        closeAll();
        dashboardOpen = true;
    }
    function close() {
        dashboardOpen = false;
    }
    function toggle() {
        const next = !dashboardOpen;
        closeAll();
        dashboardOpen = next;
    }

    function openQuick() {
        closeAll();
        quickOpen = true;
    }
    function closeQuick() {
        quickOpen = false;
    }
    function toggleQuick() {
        const next = !quickOpen;
        closeAll();
        quickOpen = next;
    }

    function openSettings() {
        closeAll();
        settingsOpen = true;
    }
    function closeSettings() {
        settingsOpen = false;
    }
    function toggleSettings() {
        const next = !settingsOpen;
        closeAll();
        settingsOpen = next;
    }

    function openKeys() {
        closeAll();
        keysOpen = true;
    }
    function closeKeys() {
        keysOpen = false;
    }
    function toggleKeys() {
        const next = !keysOpen;
        closeAll();
        keysOpen = next;
    }
}
