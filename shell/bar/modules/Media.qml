import QtQuick
import qs
import qs.components
import qs.services

// |<  [||]  >|  artist - title  [███░░░░░]
// The title shrinks (and the progress bar disappears) to fit maxWidth.
Row {
    id: root

    property real maxWidth: 400

    readonly property int gaugeSize: 8
    readonly property real gaugeWidth: (gaugeSize + 2) * Theme.cellW
    readonly property real minTitle: Theme.cellW * 6
    readonly property real room: maxWidth - controls.width - spacing

    visible: Media.active
    spacing: Theme.cellW

    Row {
        id: controls
        spacing: Theme.cellW

        Txt {
            text: "|<"
            color: Theme.dim
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.previous()
            }
        }
        Txt {
            text: Media.playing ? "[||]" : "[ >]"
            font.bold: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle()
            }
        }
        Txt {
            text: ">|"
            color: Theme.dim
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.next()
            }
        }
    }

    Txt {
        id: title
        readonly property bool gaugeFits: root.room - root.gaugeWidth - root.spacing >= root.minTitle
        readonly property real available: gaugeFits ? root.room - root.gaugeWidth - root.spacing : root.room

        visible: available >= root.minTitle
        width: Math.max(0, Math.min(implicitWidth, available))
        elide: Text.ElideRight
        text: Media.artist !== "" ? `${Media.artist} - ${Media.title}` : Media.title
    }

    Gauge {
        visible: title.visible && title.gaugeFits
        size: root.gaugeSize
        value: Media.progress
    }
}
