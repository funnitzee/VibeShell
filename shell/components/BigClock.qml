import QtQuick
import qs

// Big LED-style text (digits and ':') built from rectangles on a 3x5 pixel font.
// A pixel is 2 cells wide and 1 cell tall, so everything stays on the cell grid.
Item {
    id: root

    property string text: "00:00"
    property color lit: Theme.fg
    property color unlit: Theme.surface

    readonly property real pw: Theme.cellW * 2
    readonly property real ph: Theme.cellH

    readonly property var font: ({
            "0": ["111", "101", "101", "101", "111"],
            "1": ["010", "110", "010", "010", "111"],
            "2": ["111", "001", "111", "100", "111"],
            "3": ["111", "001", "111", "001", "111"],
            "4": ["101", "101", "111", "001", "001"],
            "5": ["111", "100", "111", "001", "111"],
            "6": ["111", "100", "111", "101", "111"],
            "7": ["111", "001", "001", "001", "001"],
            "8": ["111", "101", "111", "101", "111"],
            "9": ["111", "101", "111", "001", "111"],
            ":": ["0", "1", "0", "1", "0"],
            " ": ["0", "0", "0", "0", "0"]
        })

    // One entry per pixel: { x, y, on }. The gap between characters is one cell.
    readonly property var layout: {
        const pixels = [];
        let x = 0;
        for (const ch of text) {
            const glyph = font[ch] ?? font[" "];
            const w = glyph[0].length;
            for (let row = 0; row < 5; row++)
                for (let col = 0; col < w; col++)
                    pixels.push({
                        x: x + col * pw,
                        y: row * ph,
                        on: glyph[row][col] === "1"
                    });
            x += w * pw + Theme.cellW;
        }
        return {
            pixels,
            width: Math.max(0, x - Theme.cellW)
        };
    }

    implicitWidth: layout.width
    implicitHeight: 5 * ph

    Repeater {
        model: root.layout.pixels

        delegate: Rectangle {
            required property var modelData
            x: Math.round(modelData.x)
            y: Math.round(modelData.y)
            width: Math.round(root.pw) - 2
            height: Math.round(root.ph) - 2
            color: modelData.on ? root.lit : root.unlit
        }
    }
}
