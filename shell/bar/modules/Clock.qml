import Quickshell
import QtQuick
import qs
import qs.components

Txt {
    text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
