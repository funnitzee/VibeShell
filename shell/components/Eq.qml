import QtQuick
import qs

// Fake equalizer: one block character per bar, animated while playing,
// flat when stopped. Looks like music, measures nothing.
Txt {
    id: root

    property int bars: 8
    property bool active: false

    property var levels: Array(bars).fill(0)

    color: Theme.dim
    text: levels.map(v => "▁▂▃▄▅▆▇█"[v]).join("")

    onActiveChanged: {
        if (!active)
            levels = Array(bars).fill(0);
    }

    Timer {
        interval: 170
        repeat: true
        running: root.active && Theme.animations
        onTriggered: root.levels = Array.from({
            length: root.bars
        }, () => Math.floor(Math.random() * 8))
    }
}
