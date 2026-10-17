import QtQuick
import qs
import qs.components
import qs.services

// cpu ▁▂▃▅▇ 12%   mem [███░░░░░] 35%
Row {
    spacing: Theme.cellW * 2

    Row {
        spacing: Theme.cellW

        Txt {
            text: "cpu"
            color: Theme.dim
        }
        Spark {
            values: Stats.cpuHistory
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
            value: Stats.mem
        }
        Txt {
            text: `${Stats.mem}%`.padStart(4)
        }
    }
}
