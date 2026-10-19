pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Screenshots for the :shot command. Uses grim (the screencopy CLI every niri
// user already has or can install) and slurp for the region mode. Shots go to
// $XDG_PICTURES_DIR/Screenshots (~/Pictures/Screenshots by default) and are
// copied to the clipboard when wl-copy is available. Everything degrades
// gracefully when the tools are missing.
Singleton {
    id: root

    property string tool: ""
    property bool hasRegion: false
    property bool hasClip: false

    readonly property bool available: tool !== ""
    readonly property string dir: (Quickshell.env("XDG_PICTURES_DIR")
        || (Quickshell.env("HOME") ?? "") + "/Pictures")
        + "/Screenshots"

    function stamp() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
    }

    // Kick off a capture and return { close, message } for the palette. The
    // result is reported as a notification once the process exits; a cancelled
    // region (slurp exits non-zero) stays quiet.
    function capture(mode) {
        if (!available)
            return {
                close: false,
                message: "screenshot needs grim (and slurp for region)"
            };
        if (mode === "region" && !hasRegion)
            return {
                close: false,
                message: "region shots need slurp"
            };
        const file = `${dir}/shot-${stamp()}.png`;
        const steps = [`mkdir -p "${dir}" || exit 1`];
        if (mode === "region")
            steps.push(`region=$(slurp) || exit 40`, `grim -g "$region" "${file}" || exit 2`);
        else
            steps.push(`grim "${file}" || exit 2`);
        steps.push(`[ -s "${file}" ] || exit 3`);
        steps.push(hasClip ? `wl-copy < "${file}"` : "true", "exit 0");
        cap.command = ["sh", "-c", steps.join("; ")];
        cap.running = true;
        return {
            close: true,
            message: `saving to ${file}`
        };
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "vibeshell", summary, body]);
    }

    Component.onCompleted: probe.running = true

    Process {
        id: cap
        running: false
        onExited: (code, status) => {
            if (code === 0)
                root.notify("screenshot saved", root.dir);
            else if (code === 40)
                ; // region selection cancelled
            else {
                console.warn("VibeShell: screenshot failed, exit", code);
                root.notify("screenshot failed", "is grim working?");
            }
        }
    }

    Process {
        id: probe
        running: false
        command: ["sh", "-c", "for b in grim slurp wl-copy; do command -v $b >/dev/null 2>&1 && echo $b; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l !== "");
                root.tool = found.includes("grim") ? "grim" : "";
                root.hasRegion = found.includes("slurp");
                root.hasClip = found.includes("wl-copy");
            }
        }
    }
}
