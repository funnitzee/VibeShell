import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Polkit authentication agent. Shows a small TUI prompt whenever a privileged
// action (mounting a disk, managing a system service, ...) asks for
// authentication. Registration happens automatically through
// Quickshell.Services.Polkit; if another agent (gnome-polkit, polkit-kde, ...)
// is already running this one stays dormant and the window never appears.
Scope {
    id: root

    readonly property bool active: agent.isActive && agent.flow !== null
    readonly property var flow: agent.flow

    function submit() {
        if (root.active)
            root.flow.submit(prompt.text);
        prompt.text = "";
    }

    function cancel() {
        if (root.active)
            root.flow.cancelAuthenticationRequest();
        prompt.text = "";
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: agent

        function onAuthenticationRequestStarted() {
            prompt.text = "";
            prompt.forceActiveFocus();
        }
    }

    PanelWindow {
        id: win

        screen: Niri.focusedScreen
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-polkit"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        TuiFrame {
            id: frame

            anchors.centerIn: parent
            cols: 46
            rows: 7
            title: "authentication"
            color: Theme.urgent

            Txt {
                width: parent.width
                elide: Text.ElideRight
                text: root.flow ? root.flow.message : ""
            }

            Txt {
                y: 1 * Theme.cellH
                color: Theme.dim
                text: root.flow ? root.flow.inputPrompt : ""
            }

            TextInput {
                id: prompt

                y: 2 * Theme.cellH
                width: parent.width
                height: Theme.cellH
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                onAccepted: root.submit()
                Keys.onEscapePressed: root.cancel()

                Component.onCompleted: forceActiveFocus()
            }

            Txt {
                y: 3 * Theme.cellH
                width: parent.width
                elide: Text.ElideRight
                color: Theme.urgent
                visible: root.flow && root.flow.supplementaryMessage !== ""
                text: root.flow ? root.flow.supplementaryMessage : ""
            }

            Txt {
                y: 4 * Theme.cellH
                color: Theme.dim
                text: "enter authenticate    esc cancel"
            }
        }
    }
}
