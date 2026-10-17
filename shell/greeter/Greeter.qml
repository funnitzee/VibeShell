pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Quickshell.Io
import QtQuick
import qs
import qs.components
import qs.services

// TUI-style greeter screen shown on greetd's display.
Scope {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property bool active: Greeter.active

    PanelWindow {
        id: win
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-greeter"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }


        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }

        FocusScope {
            id: input
            anchors.fill: parent
            focus: win.visible

            property bool cursorOn: true

            Component.onCompleted: input.forceActiveFocus()
            onActiveFocusChanged: {
                if (!activeFocus && win.visible)
                    input.forceActiveFocus();
            }

            Timer {
                interval: 600
                running: win.visible
                repeat: true
                triggeredOnStart: true
                onTriggered: input.cursorOn = !input.cursorOn
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    Greeter.submit();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backspace) {
                    if (Greetd.state === Greetd.Authenticating) {
                        Greeter.password = Greeter.password.slice(0, -1);
                    } else if (Greetd.state === Greetd.Inactive) {
                        Greeter.username = Greeter.username.slice(0, -1);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    if (Greetd.state === Greetd.Authenticating) {
                        Greeter.cancel();
                    }
                    event.accepted = true;
                } else if (event.text && event.text.charCodeAt(0) >= 0x20) {
                    if (Greetd.state === Greetd.Authenticating) {
                        Greeter.password += event.text;
                    } else if (Greetd.state === Greetd.Inactive) {
                        Greeter.username += event.text;
                    }
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
                    cols: 50
                    rows: 8
                    title: "login"
                    color: Theme.dim

                    Txt {
                        x: 2 * Theme.cellW
                        color: Theme.dim
                        text: Greeter.host !== "" ? `vibeshell greeter — ${Greeter.host}` : "vibeshell greeter"
                    }

                    Txt {
                        x: 2 * Theme.cellW
                        y: 2 * Theme.cellH
                        text: Greetd.state === Greetd.Authenticating ? "password:" : "username:"
                        color: Theme.dim
                    }

                    Txt {
                        visible: Greetd.state !== Greetd.Authenticating
                        x: 14 * Theme.cellW
                        y: 2 * Theme.cellH
                        text: Greeter.username
                        color: Theme.fg
                    }

                    Txt {
                        visible: Greetd.state !== Greetd.Authenticating
                        x: (14 + Greeter.username.length) * Theme.cellW
                        y: 2 * Theme.cellH
                        text: input.cursorOn ? "█" : " "
                        color: Theme.fg
                    }

                    Txt {
                        visible: Greetd.state === Greetd.Authenticating
                        x: 14 * Theme.cellW
                        y: 2 * Theme.cellH
                        text: "•".repeat(Greeter.password.length)
                        color: Theme.fg
                    }

                    Txt {
                        visible: Greetd.state === Greetd.Authenticating
                        x: (14 + Greeter.password.length) * Theme.cellW
                        y: 2 * Theme.cellH
                        text: input.cursorOn ? "█" : " "
                        color: Theme.fg
                    }

                    Txt {
                        x: 2 * Theme.cellW
                        y: 4 * Theme.cellH
                        width: 46 * Theme.cellW
                        elide: Text.ElideRight
                        color: Greeter.failed ? Theme.urgent : Theme.dim
                        text: Greeter.message !== "" ? Greeter.message :
                              Greetd.state === Greetd.Authenticating ?
                                (Greeter.authenticating ? "authenticating..." : "type password, press enter") :
                              "enter username, press enter"
                    }

                    Txt {
                        x: 2 * Theme.cellW
                        y: 6 * Theme.cellH
                        width: 46 * Theme.cellW
                        elide: Text.ElideRight
                        color: Theme.dim
                        text: Greeter.defaultUser !== "" && Greetd.state !== Greetd.Authenticating ?
                              `tab/enter to use ${Greeter.defaultUser}` : ""
                    }
                }
            }
        }
    }
}
