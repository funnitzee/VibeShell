import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Full-screen lock surface, drawn by the compositor over everything else while
// the session is locked (one instance per monitor). Type your password and press
// Enter; the locking, users and PAM live in qs.services.Lock. There is no way
// out of here but a valid password. Trigger with `Mod+Alt+L`, `:lock`, or:
//   quickshell ipc -p <shell dir> call lock lock
Scope {
    id: root

    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }
        function unlock(): void {
            Lock.unlock();
        }
        function toggle(): void {
            Lock.locked ? Lock.unlock() : Lock.lock();
        }

    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    WlSessionLock {
        id: sessionLock

        locked: Lock.locked

        WlSessionLockSurface {
            color: Theme.bg

            FocusScope {
                id: input

                anchors.fill: parent
                focus: true

                property bool cursorOn: true

                Component.onCompleted: input.forceActiveFocus()
                onActiveFocusChanged: {
                    if (!activeFocus && Lock.locked)
                        input.forceActiveFocus();
                }

                Timer {
                    interval: 600
                    running: Lock.locked && Theme.animations
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: input.cursorOn = !input.cursorOn
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        Lock.submit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace) {
                        Lock.password = Lock.password.slice(0, -1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) {
                        event.accepted = true; // no escaping the lock screen
                    } else if (event.text && event.text.charCodeAt(0) >= 0x20) {
                        Lock.password += event.text;
                        event.accepted = true;
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.cellH

                    BigClock {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.dim
                        text: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
                    }

                    TuiFrame {
                        cols: 46
                        rows: 8
                        title: "locked"
                        color: Theme.dim

                        Txt {
                            x: 2 * Theme.cellW
                            color: Theme.dim
                            text: Lock.host !== "" ? `${Lock.user}@${Lock.host}` : Lock.user
                        }

                        Txt {
                            x: 2 * Theme.cellW
                            y: 2 * Theme.cellH
                            text: "password:"
                            color: Theme.dim
                        }

                        Txt {
                            x: 12 * Theme.cellW
                            y: 2 * Theme.cellH
                            text: "•".repeat(Lock.password.length)
                            color: Theme.fg
                        }

                        Txt {
                            x: (12 + Lock.password.length) * Theme.cellW
                            y: 2 * Theme.cellH
                            text: input.cursorOn ? "█" : " "
                            color: Theme.fg
                        }

                        Txt {
                            x: 2 * Theme.cellW
                            y: 4 * Theme.cellH
                            width: 42 * Theme.cellW
                            elide: Text.ElideRight
                            color: Lock.failed ? Theme.urgent : Theme.dim
                            text: Lock.message !== "" ? Lock.message : Lock.authenticating ? "checking..." : "type your password, press enter"
                        }
                    }
                }
            }
        }
    }
}
