pragma Singleton

import Quickshell

// Shared open/closed state of popups, so the bar can open what other files draw.
Singleton {
    property bool dashboardOpen: false
    property bool quickOpen: false

    function open() {
        quickOpen = false;
        dashboardOpen = true;
    }
    function close() {
        dashboardOpen = false;
    }
    function toggle() {
        dashboardOpen = !dashboardOpen;
        if (dashboardOpen)
            quickOpen = false;
    }

    function openQuick() {
        dashboardOpen = false;
        quickOpen = true;
    }
    function closeQuick() {
        quickOpen = false;
    }
    function toggleQuick() {
        quickOpen = !quickOpen;
        if (quickOpen)
            dashboardOpen = false;
    }
}
