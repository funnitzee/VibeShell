pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import qs

// Screen lock. The real locking is done by the compositor through
// ext-session-lock-v1 (niri supports it), so the session stays safe even if the
// shell is busy; this holds the shared state and authenticates with PAM. The
// surface itself is qs.lock.LockScreen and the idle timeout is qs.services.Idle.
// Lock with `:lock`, the `lock` IPC handler (bound to Mod+Alt+L) or over IPC:
//   quickshell ipc -p <shell dir> call lock lock
Singleton {
    id: root

    // Requested lock state, followed by the WlSessionLock in LockScreen.
    property bool locked: false
    // Password being typed on the lock surface.
    property string password: ""
    property bool authenticating: false
    property bool failed: false
    // Last thing to show, e.g. a PAM error.
    property string message: ""

    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    property string host: ""

    // Clear a previous failure as soon as a new password is typed.
    onPasswordChanged: {
        if (password !== "") {
            root.failed = false;
            root.message = "";
        }
    }

    function lock() {
        if (root.locked)
            return;
        root.password = "";
        root.authenticating = false;
        root.failed = false;
        root.message = "";
        Ui.closeAll();
        root.locked = true;
    }

    function unlock() {
        root.locked = false;
        root.password = "";
        root.authenticating = false;
        root.failed = false;
        root.message = "";
    }

    // Try the typed password (Enter on the lock surface).
    function submit() {
        if (root.authenticating || root.password === "")
            return;
        root.authenticating = true;
        root.failed = false;
        root.message = "";
        if (!pam.start()) {
            root.authenticating = false;
            root.failed = true;
            root.message = "could not start authentication";
        }
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.host = text().trim()
    }

    // Lid close -> lock. Polled from /proc/acpi (works on any laptop; no output
    // on desktops, so the poll is just a no-op there).
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!lidQuery.running)
            lidQuery.running = true
    }

    Process {
        id: lidQuery
        command: ["sh", "-c", "cat /proc/acpi/button/lid/*/state 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("closed"))
                    root.lock();
            }
        }
    }

    PamContext {
        id: pam

        // "login" works on every Arch box; override with `lock.service` or point
        // VIBESHELL_PAM_DIR at a custom directory (handy for testing).
        config: Settings.data.lock.service
        configDirectory: Quickshell.env("VIBESHELL_PAM_DIR") || "/etc/pam.d"

        // pam_unix asks for the password once; answer with what was typed.
        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.password);
        }

        onCompleted: result => {
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.password = "";
            root.failed = true;
            root.message = result === PamResult.MaxTries ? "too many attempts" : result === PamResult.Error ? "authentication error" : "wrong password";
        }
    }
}
