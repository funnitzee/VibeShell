pragma Singleton

import Quickshell

// Shared open/closed state of popups, so the bar can open what other files draw.
Singleton {
    property bool dashboardOpen: false

    function open() {
        dashboardOpen = true;
    }
    function close() {
        dashboardOpen = false;
    }
    function toggle() {
        dashboardOpen = !dashboardOpen;
    }
}
