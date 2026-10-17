import QtQuick
import qs
import qs.components
import qs.services

// cpu ▁▂▃▅▇ 12%   mem [███░░░] 35%   bat 82%+   (click: quick settings)
Item {
    id: root

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.toggleQuick()
    }

    Row {
        id: content
        spacing: Theme.cellW * 2

        Row {
            spacing: Theme.cellW

            Txt {
                text: "cpu"
                color: Theme.dim
            }
            Spark {
                values: Stats.cpuHistory.slice(-8)
            }
            Txt {
                text: `${Stats.cpu}%`.padStart(4)
            }
        }

        Row {
            spacing: Theme.cellW

            Txt {
                text: "mem"
                color: Theme.dim
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
            spacing: Theme.cellW

            Txt {
                text: "bat"
                color: Theme.dim
            }
            Txt {
                text: `${Power.percent}%` + (Power.charging ? "+" : "")
                color: !Power.charging && Power.percent <= 15 ? Theme.accent : Theme.fg
                font.bold: !Power.charging && Power.percent <= 15
            }
        }
    }
}
