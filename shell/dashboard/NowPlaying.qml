import QtQuick
import qs
import qs.components
import qs.services

// Dashboard media block: title, artist, transport, seekable progress, equalizer.
Item {
    id: root

    readonly property real w: 30 * Theme.cellW

    width: w
    height: 8 * Theme.cellH

    Txt {
        visible: !Media.active
        color: Theme.dim
        text: "media  --"
    }

    Txt {
        visible: Media.active
        width: root.w
        elide: Text.ElideRight
        text: Media.title
    }

    Txt {
        visible: Media.active
        y: Theme.cellH
        width: root.w
        elide: Text.ElideRight
        color: Theme.dim
        text: Media.artist !== "" ? Media.artist : Media.identity
    }

    Row {
        visible: Media.active
        y: 3 * Theme.cellH
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
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.dim
            text: `${Media.format(Media.position)} / ${Media.format(Media.length)}`
        }
    }

    Gauge {
        visible: Media.active
        y: 4 * Theme.cellH
        size: 12
        value: Media.progress
        color: Media.canSeek ? Theme.dim : Theme.border

        MouseArea {
            anchors.fill: parent
            enabled: Media.canSeek
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => Media.seekTo(mouse.x / parent.width * Media.length)
        }
    }

    Eq {
        visible: Media.active
        y: 6 * Theme.cellH
        bars: 10
        active: Media.playing
    }

    Txt {
        visible: Media.active && Media.canSeek
        y: 7 * Theme.cellH
        color: Theme.border
        text: "click the bar to seek"
    }
}
