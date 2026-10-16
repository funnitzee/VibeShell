import QtQuick
import qs
import qs.components
import qs.services

Row {
    spacing: 14

    Txt {
        text: `cpu ${Stats.cpu}%`
        color: Theme.dim
    }
    Txt {
        text: `mem ${Stats.mem}%`
        color: Theme.dim
    }
}
