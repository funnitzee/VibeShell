#!/usr/bin/env python3
"""A fake MPRIS media player for developing and screenshotting VibeShell.

Registers org.mpris.MediaPlayer2.vibeshell_demo on the session bus, plays through a
short list of made-up tracks and reacts to PlayPause / Next / Previous. Needs
dbus-python and PyGObject. Run it on a private bus (dbus-run-session) when taking
screenshots, so nothing from the real session shows up.
"""

import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

BUS_NAME = "org.mpris.MediaPlayer2.vibeshell_demo"
OBJ = "/org/mpris/MediaPlayer2"
ROOT = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"

# (title, artist, album, seconds)
TRACKS = [
    ("Midnight Terminal", "The Daemons", "Foreground Jobs", 215),
    ("Segfault Serenade", "Null Pointer", "Undefined Behavior", 187),
    ("sudo make me a sandwich", "Root Access", "Permission Denied", 242),
]


class MockPlayer(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(dbus.service.BusName(BUS_NAME, bus), OBJ)
        self.index = 0
        self.playing = True
        self.base = 37.0  # seconds into the track when `t0` was taken
        self.t0 = time.monotonic()

    # -- state -------------------------------------------------------------
    @property
    def track(self):
        return TRACKS[self.index]

    def position(self):
        pos = self.base + (time.monotonic() - self.t0 if self.playing else 0.0)
        return min(pos, float(self.track[3]))

    def _set_position(self, seconds):
        self.base = seconds
        self.t0 = time.monotonic()

    def _metadata(self):
        title, artist, album, seconds = self.track
        return dbus.Dictionary(
            {
                "mpris:trackid": dbus.ObjectPath(f"/vibeshell/demo/track{self.index}"),
                "mpris:length": dbus.Int64(seconds * 1_000_000),
                "xesam:title": dbus.String(title),
                "xesam:artist": dbus.Array([artist], signature="s"),
                "xesam:album": dbus.String(album),
            },
            signature="sv",
        )

    def _props(self, iface):
        if iface == ROOT:
            return {
                "CanQuit": dbus.Boolean(False),
                "CanRaise": dbus.Boolean(False),
                "HasTrackList": dbus.Boolean(False),
                "Identity": dbus.String("VibeShell demo player"),
                "SupportedUriSchemes": dbus.Array([], signature="s"),
                "SupportedMimeTypes": dbus.Array([], signature="s"),
            }
        if iface == PLAYER:
            return {
                "PlaybackStatus": dbus.String("Playing" if self.playing else "Paused"),
                "LoopStatus": dbus.String("None"),
                "Rate": dbus.Double(1.0),
                "MinimumRate": dbus.Double(1.0),
                "MaximumRate": dbus.Double(1.0),
                "Shuffle": dbus.Boolean(False),
                "Metadata": self._metadata(),
                "Volume": dbus.Double(1.0),
                "Position": dbus.Int64(int(self.position() * 1_000_000)),
                "CanGoNext": dbus.Boolean(True),
                "CanGoPrevious": dbus.Boolean(True),
                "CanPlay": dbus.Boolean(True),
                "CanPause": dbus.Boolean(True),
                "CanSeek": dbus.Boolean(True),
                "CanControl": dbus.Boolean(True),
            }
        return {}

    def _changed(self, *names):
        props = self._props(PLAYER)
        self.PropertiesChanged(PLAYER, {n: props[n] for n in names}, [])

    # -- org.freedesktop.DBus.Properties -----------------------------------
    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ss", out_signature="v")
    def Get(self, iface, name):
        return self._props(iface)[name]

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return self._props(iface)

    @dbus.service.method(dbus.PROPERTIES_IFACE, in_signature="ssv")
    def Set(self, iface, name, value):
        pass

    @dbus.service.signal(dbus.PROPERTIES_IFACE, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    # -- org.mpris.MediaPlayer2 --------------------------------------------
    @dbus.service.method(ROOT)
    def Raise(self):
        pass

    @dbus.service.method(ROOT)
    def Quit(self):
        pass

    # -- org.mpris.MediaPlayer2.Player -------------------------------------
    def _play(self, playing):
        self._set_position(self.position())
        self.playing = playing
        self._changed("PlaybackStatus")

    def _goto(self, index):
        self.index = index % len(TRACKS)
        self._set_position(0.0)
        self._changed("Metadata", "PlaybackStatus")

    @dbus.service.method(PLAYER)
    def PlayPause(self):
        self._play(not self.playing)

    @dbus.service.method(PLAYER)
    def Play(self):
        self._play(True)

    @dbus.service.method(PLAYER)
    def Pause(self):
        self._play(False)

    @dbus.service.method(PLAYER)
    def Stop(self):
        self._play(False)

    @dbus.service.method(PLAYER)
    def Next(self):
        self._goto(self.index + 1)

    @dbus.service.method(PLAYER)
    def Previous(self):
        self._goto(self.index - 1)

    @dbus.service.method(PLAYER, in_signature="x")
    def Seek(self, offset):
        # MPRIS offsets and positions are in microseconds.
        self._set_position(max(0.0, min(float(self.track[3]), self.position() + float(offset) / 1_000_000)))

    @dbus.service.method(PLAYER, in_signature="ox")
    def SetPosition(self, track_id, position):
        self._set_position(max(0.0, min(float(self.track[3]), float(position) / 1_000_000)))

    @dbus.service.method(PLAYER, in_signature="s")
    def OpenUri(self, uri):
        pass

    def tick(self):
        if self.playing and self.position() >= self.track[3]:
            self._goto(self.index + 1)
        return True


def main():
    DBusGMainLoop(set_as_default=True)
    player = MockPlayer(dbus.SessionBus())
    GLib.timeout_add_seconds(1, player.tick)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
