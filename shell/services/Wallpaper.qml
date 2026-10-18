pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Wallpaper control. swww is preferred when installed, otherwise swaybg. The
// current path is persisted in settings (wallpaper.path) and next/prev cycle
// through the images in wallpaper.dir. If neither tool exists the `:wallpaper`
// command reports that and nothing else happens.
Singleton {
    id: root

    property string current: Settings.data.wallpaper.path ?? ""
    // File list in wallpaper.dir, refreshed on demand.
    property var files: []
    property int index: -1

    // "swww", "swaybg" or "" when neither is installed.
    property string tool: ""
    readonly property bool available: tool !== ""

    function expand(p) {
        const home = Quickshell.env("HOME");
        return p.replace(/^~(?=\/|$)/, home);
    }

    // Set the wallpaper to a concrete file path. Saves it to settings.
    function set(path) {
        const full = expand(path);
        root.current = full;
        Settings.set("wallpaper.path", full);
        _apply(full);
    }

    // Cycle to the next file in wallpaper.dir.
    function next() {
        if (files.length === 0) {
            refresh();
            return;
        }
        root.index = (root.index + 1) % files.length;
        set(files[root.index]);
    }

    function prev() {
        if (files.length === 0) {
            refresh();
            return;
        }
        root.index = (root.index - 1 + files.length) % files.length;
        set(files[root.index]);
    }

    function refresh() {
        if (!list.running)
            list.running = true;
    }

    // Detached on purpose: swaybg is long-running, so it must outlive the shell
    // process object or every later change would be blocked by it.
    function _apply(path) {
        if (!available || path === "")
            return;
        if (tool === "swww")
            Quickshell.execDetached(["sh", "-c", "pkill -x swaybg 2>/dev/null; swww-daemon >/dev/null 2>&1 & sleep 0.3; swww img \"$1\"", "sh", path]);
        else
            Quickshell.execDetached(["sh", "-c", "pkill -x swww-daemon 2>/dev/null; pkill -x swaybg 2>/dev/null; sleep 0.1; swaybg -m fill -i \"$1\" >/dev/null 2>&1 &", "sh", path]);
    }

    Component.onCompleted: refresh()

    onAvailableChanged: if (available && current !== "")
        _apply(current)

    // Detect which wallpaper tool is installed (once, at startup).
    Process {
        id: probe
        command: ["sh", "-c", "if command -v swww >/dev/null 2>&1; then echo swww; elif command -v swaybg >/dev/null 2>&1; then echo swaybg; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.tool = text.trim()
        }
    }

    // List images in wallpaper.dir.
    Process {
        id: list
        command: ["sh", "-c", `find "${root.expand(Settings.data.wallpaper.dir)}" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l !== "");
                root.files = found;
                root.index = found.indexOf(root.current);
            }
        }
    }
}
