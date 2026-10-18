pragma Singleton

import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Io
import QtQuick
import qs

// Greeter service handling Greetd authentication (for display manager).
// Shares similar UI feel to the lock screen but drives greetd.
Singleton {
    id: root

    IpcHandler {
        target: "greeter"
        function start(): void {
            root.start();
        }
        function stop(): void {
            root.cancel();
        }
        function submit(): void {
            root.submit();
        }
    }

    property bool active: false
    property string username: ""
    property string password: ""
    property bool authenticating: false
    property bool failed: false
    property string message: ""
    property string host: ""

    readonly property string defaultUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    // Shown automatically when the shell is started as greetd's greeter session
    // (greetd exports GREETD_SOCK to the greeter only).
    Component.onCompleted: {
        if (Quickshell.env("GREETD_SOCK"))
            root.start();
    }

    onPasswordChanged: {
        if (password !== "") {
            root.failed = false;
            root.message = "";
        }
    }

    function start() {
        if (root.active)
            return;
        root.username = root.defaultUser;
        root.password = "";
        root.authenticating = false;
        root.failed = false;
        root.message = "";
        root.active = true;
        Ui.closeAll();
    }

    function cancel() {
        if (root.authenticating && Greetd.state === Greetd.Authenticating) {
            Greetd.cancelSession();
        }
        root.active = false;
        root.authenticating = false;
        root.failed = false;
        root.password = "";
        root.message = "";
    }

    function submit() {
        if (!root.active || root.authenticating)
            return;
        if (Greetd.state === Greetd.Inactive) {
            if (root.username.trim() === "")
                return;
            root.authenticating = true;
            root.message = "";
            Greetd.createSession(root.username.trim());
            return;
        }
        if (Greetd.state === Greetd.Authenticating && Greetd.responseRequired) {
            root.authenticating = true;
            Greetd.respond(root.password);
            root.password = "";
        }
    }

    function launchSession() {
        // Launch default shell/command - greetd will start the session
        Greetd.launch(null);
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.host = text().trim()
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            root.authenticating = false;
            root.message = message;
            root.failed = error;
        }

        function onAuthFailure(message) {
            root.authenticating = false;
            root.failed = true;
            root.message = message || "authentication failed";
            root.password = "";
        }

        function onReadyToLaunch() {
            root.authenticating = false;
            root.message = "starting session...";
            // Small delay not needed, launch immediately
            Greetd.launch(null);
        }

        function onLaunched() {
            root.active = false;
            root.authenticating = false;
        }

        function onError(error) {
            root.authenticating = false;
            root.failed = true;
            root.message = error;
        }

        function onStateChanged() {
            if (Greetd.state === Greetd.Authenticating) {
                root.authenticating = Greetd.responseRequired;
            } else if (Greetd.state === Greetd.Inactive) {
                root.authenticating = false;
            }
        }
    }
}
