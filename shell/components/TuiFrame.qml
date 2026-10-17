import QtQuick
import qs

// Terminal-style frame measured in character cells (cols x rows) with a title cut
// into the top border. The lines are drawn as 1px rectangles through the middle of
// the outermost cells, so they stay gap-free with any font. Children go into the
// inner area: (cols - 2) x (rows - 2) cells.
Item {
    id: root

    property int cols: 40
    property int rows: 10
    property string title: ""
    // Frame rows (0 = top border) that get a horizontal divider.
    property var dividers: []
    property color color: Theme.border
    property color background: Theme.bg

    default property alias content: inner.data

    implicitWidth: cols * Theme.cellW
    implicitHeight: rows * Theme.cellH

    Rectangle {
        anchors.fill: parent
        color: root.background
    }

    Rectangle {
        x: Math.round(Theme.cellW / 2)
        y: Math.round(Theme.cellH / 2)
        width: Math.round((root.cols - 1) * Theme.cellW)
        height: Math.round((root.rows - 1) * Theme.cellH)
        color: "transparent"
        border.width: 1
        border.color: root.color
    }

    Repeater {
        model: root.dividers
        delegate: Rectangle {
            required property int modelData
            x: Math.round(Theme.cellW / 2)
            y: Math.round(modelData * Theme.cellH + Theme.cellH / 2)
            width: Math.round((root.cols - 1) * Theme.cellW) + 1
            height: 1
            color: root.color
        }
    }

    // Title: a background-colored patch interrupts the top line.
    Rectangle {
        visible: root.title !== ""
        x: Math.round(Theme.cellW * 2)
        y: 0
        width: Math.round((root.title.length + 2) * Theme.cellW)
        height: Math.ceil(Theme.cellH)
        color: root.background

        Txt {
            x: Theme.cellW
            text: root.title
            color: Theme.fg
        }
    }

    Item {
        id: inner
        x: Theme.cellW
        y: Theme.cellH
        width: (root.cols - 2) * Theme.cellW
        height: (root.rows - 2) * Theme.cellH
    }
}
