import QtQuick
import qs

// Horizontal gauge: [████░░░░]. Value is a percentage (0-100).
Txt {
    property real value: 0
    property int size: 8

    color: Theme.dim
    text: {
        const n = Math.round(Math.max(0, Math.min(100, value)) / 100 * size);
        return "[" + "█".repeat(n) + "░".repeat(size - n) + "]";
    }
}
