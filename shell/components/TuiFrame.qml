import QtQuick
import qs

// Box-drawing frame measured in character cells (cols x rows) with a title in the
// top border. Children go into the inner area: (cols - 2) x (rows - 2) cells.
Item {
    id: root

    property int cols: 40
    property int rows: 10
    property string title: ""
    // Frame rows (0 = top border) that get a horizontal divider joined to the sides.
    property var dividers: []
    property color color: Theme.border
    property color background: Theme.bg

    default property alias content: inner.data

    implicitWidth: cols * Theme.cellW
    implicitHeight: rows * Theme.cellH

    function sides(bar, tee) {
        const out = [];
        for (let r = 1; r < rows - 1; r++)
            out.push(dividers.includes(r) ? tee : bar);
        return out.join("\n");
    }

    component Line: Text {
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        lineHeightMode: Text.FixedHeight
        lineHeight: Theme.cellH
    }

    Rectangle {
        anchors.fill: parent
        color: root.background
    }

    // Top border: ┌─ title ────┐ (the title is drawn in the foreground color)
    Row {
        Line {
            text: root.title === "" ? "┌" : "┌─ "
        }
        Line {
            visible: root.title !== ""
            text: root.title
            color: Theme.fg
        }
        Line {
            text: (root.title === "" ? "" : " ") + "─".repeat(Math.max(0, root.cols - 2 - (root.title === "" ? 0 : root.title.length + 4))) + "┐"
        }
    }

    Line {
        x: 0
        y: Theme.cellH
        text: root.sides("│", "├")
    }
    Line {
        x: (root.cols - 1) * Theme.cellW
        y: Theme.cellH
        text: root.sides("│", "┤")
    }

    Repeater {
        model: root.dividers
        delegate: Line {
            required property int modelData
            x: Theme.cellW
            y: modelData * Theme.cellH
            text: "─".repeat(root.cols - 2)
        }
    }

    Line {
        y: (root.rows - 1) * Theme.cellH
        text: "└" + "─".repeat(root.cols - 2) + "┘"
    }

    Item {
        id: inner
        x: Theme.cellW
        y: Theme.cellH
        width: (root.cols - 2) * Theme.cellW
        height: (root.rows - 2) * Theme.cellH
    }
}
