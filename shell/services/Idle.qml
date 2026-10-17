pragma Singleton

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// Idle handling through ext-idle-notify-v1 (niri supports it). Locks the session
// after `idle.lock` seconds without input and powers the monitors off after
// `idle.screenOff` seconds; set either to 0 to disable it. Inhibitors are
// respected, so a playing video or a fullscreen game won't lock you out.
// Any input turns the monitors back on.
Singleton {
    id: root

    IdleMonitor {
        enabled: Settings.data.idle.lock > 0
        timeout: Settings.data.idle.lock
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                Lock.lock();
        }
    }

    IdleMonitor {
        enabled: Settings.data.idle.screenOff > 0
        timeout: Settings.data.idle.screenOff
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
        }
    }
}
