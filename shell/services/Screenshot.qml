pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Screenshots for the :shot command. Uses grim (the screencopy CLI every niri
// user already has or can install) and slurp for the region mode. Shots go to
// $XDG_PICTURES_DIR/Screenshots (~/Pictures/Screenshots by default) and are
// copied to the clipboard when wl-copy is available. When swappy is installed,
// ":shot edit" / ":shot region-edit" open the shot in its annotation editor.
// Everything degrades gracefully when the tools are missing.
Singleton {
    id: root

    property string tool: ""
    property bool hasRegion: false
    property bool hasClip: false
    property bool hasSwappy: false

    readonly property bool available: tool !== ""
    readonly property bool canAnnotate: hasSwappy
    readonly property string dir: (Quickshell.env("XDG_PICTURES_DIR")
        || (Quickshell.env("HOME") ?? "") + "/Pictures")
        + "/Screenshots"

    function stamp() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
    }

    // Kick off a capture and return { close, message } for the palette. mode is
    // one of full, region, edit (full + annotate) or region-edit. The result is
    // reported as a notification once the process exits; a cancelled region
    // (slurp exits non-zero) stays quiet.
    function capture(mode) {
        let base = mode;
        if (mode === "edit")
            base = "full";
        else if (mode === "region-edit")
            base = "region";
        if (base !== "full" && base !== "region")
            return {
                close: false,
                message: "usage: :shot [full|region|edit|region-edit]"
            };
        if (!available)
            return {
                close: false,
                message: "screenshot needs grim (and slurp for region)"
            };
        if (base === "region" && !hasRegion)
            return {
                close: false,
                message: "region shots need slurp"
            };
        const annotate_ = mode !== base;
        if (annotate_ && !hasSwappy)
            return {
                close: false,
                message: "annotation needs swappy"
            };

        const file = `${dir}/shot-${stamp()}.png`;
        const steps = [`mkdir -p "${dir}" || exit 1`];
        if (base === "region")
            steps.push(`region=$(slurp) || exit 40`, `grim -g "$region" "${file}" || exit 2`);
        else
            steps.push(`grim "${file}" || exit 2`);
        steps.push(`[ -s "${file}" ] || exit 3`);
        if (annotate_)
            steps.push("exit 0"); // swappy takes over from here
        else
            steps.push(hasClip ? `wl-copy < "${file}"` : "true", "exit 0");

        cap.file = file;
        cap.annotate = annotate_;
        cap.command = ["sh", "-c", steps.join("; ")];
        cap.running = true;
        return {
            close: true,
            message: annotate_ ? `editing ${file}` : `saving to ${file}`
        };
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "vibeshell", summary, body]);
    }

    // Screenshot keys (Print / Shift+Print) call these via the installer's binds.
    IpcHandler {
        target: "shot"

        function full(): void {
            root.capture("full");
        }
        function region(): void {
            root.capture("region");
        }
    }

    Component.onCompleted: probe.running = true

    Process {
        id: cap
        property string file: ""
        property bool annotate: false
        running: false
        onExited: (code, status) => {
            if (code === 0) {
                if (cap.annotate) {
                    Quickshell.execDetached(["swappy", "-f", cap.file]);
                    return;
                }
                root.notify("screenshot saved", root.dir);
            } else if (code === 40)
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
        command: ["sh", "-c", "for b in grim slurp wl-copy swappy; do command -v $b >/dev/null 2>&1 && echo $b; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l !== "");
                root.tool = found.includes("grim") ? "grim" : "";
                root.hasRegion = found.includes("slurp");
                root.hasClip = found.includes("wl-copy");
                root.hasSwappy = found.includes("swappy");
            }
        }
    }
}
