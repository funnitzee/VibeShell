import Quickshell
import QtQuick
import qs

// One floating bar per screen.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            top: Theme.gap
            left: Theme.gap
            right: Theme.gap
        }

        implicitHeight: Theme.barHeight
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            border.width: Theme.borderWidth
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
            }
        }
    }
}
