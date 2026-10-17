import Quickshell
import QtQuick
import qs
import qs.components
import qs.services

// Click to toggle the dashboard.
Txt {
    text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.toggle()
    }
}
