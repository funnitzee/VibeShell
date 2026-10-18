import QtQuick
import qs
import qs.components
import qs.services

// Terminal-style workspace list: the active one is shown as [n].
Row {
    id: root

    required property string screenName

    spacing: Theme.cellW * 0.5

    Repeater {
        model: Niri.workspaces.filter(w => w.output === root.screenName)

        delegate: Txt {
            required property var modelData

            text: modelData.is_active ? `[${modelData.idx}]` : ` ${modelData.idx} `
            color: modelData.is_active ? Theme.accent : Theme.dim
            font.bold: modelData.is_active

            MouseArea {
                anchors.fill: parent
                onClicked: Niri.focusWorkspace(modelData.idx)
            }
        }
    }
}
