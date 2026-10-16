import Quickshell
import QtQuick
import qs
import qs.bar.modules

// One floating bar per screen: workspaces left, clock center, media and stats right.
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

            Workspaces {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                screenName: modelData.name
            }

            Clock {
                anchors.centerIn: parent
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18

                Media {}
                Stats {}
            }
        }
    }
}
