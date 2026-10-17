pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// The player shown in the bar and the dashboard: the one that is playing, else the first.
Singleton {
    id: root

    readonly property var player: {
        const list = Mpris.players.values;
        return list.find(p => p.isPlaying) ?? list[0] ?? null;
    }
    readonly property bool active: player !== null
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property real position: player ? player.position : 0
    readonly property real length: player ? player.length : 0
    readonly property int progress: length > 0 ? Math.round(100 * Math.min(1, position / length)) : 0
    readonly property bool canSeek: player !== null && player.canSeek && player.positionSupported
    readonly property string identity: player ? player.identity : ""

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }
    function next() {
        if (player && player.canGoNext)
            player.next();
    }
    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }
    function seekTo(seconds) {
        if (canSeek)
            player.position = Math.max(0, Math.min(length, seconds));
    }

    function format(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    // `position` does not update on its own, so poke it every second while playing.
    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.player.positionChanged()
    }
}
