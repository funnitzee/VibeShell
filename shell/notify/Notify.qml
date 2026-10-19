import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.services

// Stack of notification cards in the top-right corner. Shown whenever anything is
// tracked; each card times itself out (see NotifyCard). Dismiss the whole stack
// with `Notifications.clear()` over IPC or the palette's `:notify`.
Scope {
    IpcHandler {
        target: "notify"

        function clear(): void {
            Notifications.clear();
        }
        function dnd(): void {
            Notifications.toggleDnd();
        }
        function dndOn(): void {
            Notifications.setDnd(true);
        }
        function dndOff(): void {
            Notifications.setDnd(false);
        }
    }

    PanelWindow {
        id: win

        screen: Niri.focusedScreen
        visible: Notifications.popup.length > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "vibeshell-notify"

        // Top-right corner, clear of the bar.
        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.gap * 2 + Theme.barHeight
            right: Theme.gap * 2
        }

        implicitWidth: stack.implicitWidth
        implicitHeight: stack.implicitHeight

        Column {
            id: stack
            spacing: Theme.gap

            Repeater {
                model: Notifications.popup

                delegate: NotifyCard {
                    required property var modelData
                    notification: modelData
                }
            }
        }
    }
}
