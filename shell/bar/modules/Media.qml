import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.components

// Shows the playing (or first) MPRIS player. Click toggles play/pause.
Txt {
    id: root

    readonly property var player: {
        const list = Mpris.players.values;
        return list.find(p => p.isPlaying) ?? list[0] ?? null;
    }

    visible: player !== null
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 320)
    text: player ? `${player.isPlaying ? "[>]" : "[||]"} ${player.trackArtist} - ${player.trackTitle}` : ""

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.player && root.player.canTogglePlaying)
            root.player.togglePlaying()
    }
}
