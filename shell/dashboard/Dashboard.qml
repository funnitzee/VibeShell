import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Big TUI dashboard: LED clock, calendar, system panel and now playing.
// Open it from the clock in the bar, with `:dash` or over IPC:
//   quickshell ipc -p <shell dir> call dashboard toggle
Scope {
    id: root

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            Ui.toggle();
        }
        function open(): void {
            Ui.open();
        }
        function hide(): void {
            Ui.close();
        }
    }

    PanelWindow {
        id: win

        readonly property int cols: 96
        readonly property int rows: 18

        visible: Ui.dashboardOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-dashboard"

        // Only the top edge is anchored, so niri centers the window horizontally.
        anchors {
            top: true
        }
        margins {
            top: Theme.gap * 3 + Theme.barHeight
        }

        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        onVisibleChanged: {
            if (!visible)
                return;
            frame.forceActiveFocus();
            Niri.refreshWindowTitle();
        }

        // Click anywhere outside the frame to close.
        MouseArea {
            anchors.fill: parent
            onClicked: Ui.close()
        }

        TuiFrame {
            id: frame

            cols: win.cols
            rows: win.rows
            title: "dashboard"
            color: Theme.dim
            vDividers: [37, 63]

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                    Ui.close();
                    event.accepted = true;
                }
            }

            Calendar {
                id: calendar
                x: 38 * Theme.cellW
                y: 0
                date: clock.date
            }

            // -- left: big clock, date, uptime, focused window -----------------
            Column {
                BigClock {
                    // The colon blinks with the seconds.
                    text: Qt.formatDateTime(clock.date, clock.date.getSeconds() % 2 === 0 ? "HH:mm" : "HH mm")
                }

                Item {
                    width: 1
                    height: Theme.cellH
                }

                Txt {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM yyyy").toLowerCase() + `   wk ${calendar.week(clock.date)}`
                }

                Txt {
                    color: Theme.dim
                    text: `day ${calendar.dayOfYear(clock.date)} / ${calendar.daysInYear(clock.date)}`
                }

                Item {
                    width: 1
                    height: 2 * Theme.cellH
                }

                Row {
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "up   "
                    }
                    Txt {
                        text: SysInfo.formatUptime(SysInfo.uptime)
                    }
                }

                Row {
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "load "
                    }
                    Txt {
                        text: SysInfo.load
                    }
                }

                Item {
                    width: 1
                    height: 2 * Theme.cellH
                }

                Row {
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "win  "
                    }
                    Txt {
                        width: 28 * Theme.cellW
                        elide: Text.ElideRight
                        text: Niri.windowTitle !== "" ? Niri.windowTitle : "-"
                    }
                }
            }

            // -- right: system panel and now playing ---------------------------
            Column {
                x: 64 * Theme.cellW

                Row {
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "cpu  "
                    }
                    Spark {
                        values: Stats.cpuHistory.slice(-8)
                    }
                    Txt {
                        text: `${Stats.cpu}%`.padStart(4)
                    }
                }

                Row {
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "mem  "
                    }
                    Gauge {
                        size: 6
                        value: Stats.mem
                    }
                    Txt {
                        text: `${Stats.mem}%`.padStart(4)
                    }
                }

                Row {
                    visible: Power.present
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "bat  "
                    }
                    Txt {
                        text: `${Power.percent}%${Power.charging ? "+" : ""} ${Power.stateLabel}`
                    }
                }

                Row {
                    spacing: 0
                    Txt {
                        color: Theme.dim
                        text: "disk "
                    }
                    Gauge {
                        size: 6
                        value: SysInfo.disk
                    }
                    Txt {
                        text: `${SysInfo.disk}%`.padStart(4)
                    }
                }

                Item {
                    width: 1
                    height: 2 * Theme.cellH
                }

                NowPlaying {}
            }
        }
    }
}
