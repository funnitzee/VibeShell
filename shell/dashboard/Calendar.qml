import QtQuick
import qs
import qs.components

// The middle column of the dashboard: a month grid, monday first, today reversed.
// week() and dayOfYear() are plain helpers also used by the rest of the dashboard.
Item {
    id: root

    property var date: new Date()

    readonly property int year: date.getFullYear()
    readonly property int month: date.getMonth()
    readonly property string monthLabel: Qt.formatDate(date, "MMMM yyyy").toLowerCase()

    // One cell of the 7x6 grid: { day, other, today }.
    readonly property var grid: {
        const cells = [];
        const offset = (new Date(year, month, 1).getDay() + 6) % 7;
        const days = new Date(year, month + 1, 0).getDate();
        const prev = new Date(year, month, 0).getDate();
        for (let i = 0; i < 42; i++) {
            const n = i - offset + 1;
            if (n < 1)
                cells.push({
                    day: prev + n,
                    other: true,
                    today: false
                });
            else if (n > days)
                cells.push({
                    day: n - days,
                    other: true,
                    today: false
                });
            else
                cells.push({
                    day: n,
                    other: false,
                    today: n === date.getDate()
                });
        }
        return cells;
    }

    function week(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    function dayOfYear(d) {
        return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000);
    }

    function daysInYear(d) {
        const y = d.getFullYear();
        return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 366 : 365;
    }

    readonly property real labelW: 20 * Theme.cellW
    readonly property real dayX0: 4 * Theme.cellW

    width: 24 * Theme.cellW
    height: 8 * Theme.cellH

    Txt {
        x: root.dayX0 + (root.labelW - width) / 2
        text: root.monthLabel
    }

    Txt {
        y: Theme.cellH
        text: "    mo tu we th fr sa su"
    }

    Repeater {
        model: 6

        delegate: Txt {
            required property int index
            x: 0
            y: (2 + index) * Theme.cellH
            color: Theme.dim
            text: String(root.week(new Date(root.year, root.month, 1 - ((new Date(root.year, root.month, 1).getDay() + 6) % 7) + index * 7))).padStart(3)
        }
    }

    Repeater {
        model: root.grid

        delegate: Item {
            required property var modelData
            required property int index

            x: root.dayX0 + (index % 7) * 3 * Theme.cellW
            y: (2 + Math.floor(index / 7)) * Theme.cellH
            width: 2 * Theme.cellW
            height: Theme.cellH

            Rectangle {
                anchors.fill: parent
                color: Theme.fg
                visible: modelData.today
            }

            Txt {
                anchors.centerIn: parent
                text: String(modelData.day).padStart(2)
                color: modelData.today ? Theme.bg : modelData.other ? Theme.dim : Theme.fg
            }
        }
    }
}
