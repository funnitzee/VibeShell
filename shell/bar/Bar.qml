import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.bar.modules
import qs.components
import qs.services as Services

// One floating bar per screen: workspaces and media left, clock center (click: dashboard), stats right.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: panel
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

        // "Keep awake" also tells the compositor (and anything else watching
        // idle) to stay active, not just skip our own timers.
        IdleInhibitor {
            enabled: Services.Idle.stayAwake
            window: panel
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            border.width: Theme.borderWidth
            border.color: Theme.border

            Workspaces {
                id: workspaces
                anchors.left: parent.left
                anchors.leftMargin: Theme.cellW * 1.5
                anchors.verticalCenter: parent.verticalCenter
                screenName: modelData.name
            }

            Media {
                anchors.left: workspaces.right
                anchors.leftMargin: Theme.cellW * 2
                anchors.verticalCenter: parent.verticalCenter
                maxWidth: clock.x - x - Theme.cellW * 3
            }

            Clock {
                id: clock
                anchors.centerIn: parent
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.cellW * 1.5
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.cellW * 2

                Tray {}
                Stats {}
            }
        }
    }
}
