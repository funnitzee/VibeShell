import QtQuick
import qs

// Sparkline from block characters: ▁▂▃▄▅▆▇█. Values are percentages (0-100).
Txt {
    property var values: []

    readonly property string blocks: "▁▂▃▄▅▆▇█"

    color: Theme.dim
    text: values.map(v => blocks[Math.max(0, Math.min(7, Math.floor(v / 100 * 8)))]).join("")
}
