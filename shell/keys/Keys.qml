import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Keybind cheatsheet overlay (`:keys`). A read-only scrollable list of the keys
// VibeShell adds plus the niri bindings it expects, so new users have one place
// to look. j/k scroll, g/G jump, esc/q close.
Scope {
    id: root

    readonly property var groups: [
        {
            title: "shell",
            rows: [
                ["Mod+;", "command palette"],
                ["Mod+P", "dashboard"],
                ["Mod+S", "quick settings"],
                ["Mod+Shift+S", "settings window"],
                ["Mod+/", "keybinds (this)"],
                ["Mod+Alt+L", "lock the screen"]
            ]
        },
        {
            title: "niri",
            rows: [
                ["Mod+H/J/K/L", "focus left/down/up/right"],
                ["Mod+Shift+H/J/K/L", "move column/window"],
                ["Mod+1..9", "focus workspace"],
                ["Mod+Shift+1..9", "move to workspace"],
                ["Mod+R / Mod+Shift+R", "cycle column width"],
                ["Mod+F", "maximize column"],
                ["Mod+V", "toggle floating"],
                ["Mod+O", "toggle overview"],
                ["Mod+Return", "terminal"],
                ["Mod+Shift+E", "quit niri"]
            ]
        },
        {
            title: "commands",
            rows: [
                [":ws <n>", "focus workspace"],
                [":shot [mode]", "screenshot"],
                [":clip", "clipboard history"],
                [":emoji", "emoji picker"],
                [":power [profile]", "power menu / profile"],
                [":night", "toggle night light"],
                [":theme [name]", "color palette"],
                [":help", "list all commands"]
            ]
        }
    ]

    // One flat list of lines, headers included, so scrolling is trivial.
    readonly property var lines: {
        const out = [];
        for (const g of groups) {
            out.push({
                kind: "head",
                text: g.title
            });
            for (const r of g.rows)
                out.push({
                    kind: "row",
                    keys: r[0],
                    desc: r[1]
                });
        }
        return out;
    }

    readonly property int viewport: 18
    property int top: 0

    function clampTop() {
        const max = Math.max(0, lines.length - viewport);
        root.top = Math.max(0, Math.min(root.top, max));
    }

    function scroll(delta) {
        root.top += delta;
        clampTop();
    }

    IpcHandler {
        target: "keys"

        function toggle(): void {
            Ui.toggleKeys();
        }
        function open(): void {
            Ui.openKeys();
        }
        function hide(): void {
            Ui.closeKeys();
        }
    }

    PanelWindow {
        id: win

        readonly property int cols: 56

        visible: Ui.keysOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-keys"

        anchors {
            top: true
        }
        margins {
            top: Theme.gap * 3 + Theme.barHeight
        }

        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        onVisibleChanged: {
            if (visible) {
                root.top = 0;
                frame.forceActiveFocus();
            }
        }

        TuiFrame {
            id: frame

            cols: win.cols
            rows: root.viewport + 4
            title: "keybinds"
            color: Theme.dim
            dividers: [1]

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                case Qt.Key_Q:
                    Ui.closeKeys();
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                case Qt.Key_J:
                    root.scroll(1);
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                case Qt.Key_K:
                    root.scroll(-1);
                    event.accepted = true;
                    break;
                case Qt.Key_PageDown:
                    root.scroll(root.viewport);
                    event.accepted = true;
                    break;
                case Qt.Key_PageUp:
                    root.scroll(-root.viewport);
                    event.accepted = true;
                    break;
                case Qt.Key_G:
                    root.top = event.modifiers & Qt.ShiftModifier ? root.lines.length : 0;
                    root.clampTop();
                    event.accepted = true;
                    break;
                }
            }

            Repeater {
                model: root.lines.slice(root.top, root.top + root.viewport)

                delegate: Item {
                    required property var modelData
                    required property int index

                    y: (1 + index) * Theme.cellH
                    width: parent.width
                    height: Theme.cellH

                    Txt {
                        x: 2 * Theme.cellW
                        visible: modelData.kind === "head"
                        color: Theme.accent
                        font.bold: true
                        text: modelData.kind === "head" ? modelData.text : ""
                    }

                    Txt {
                        x: 4 * Theme.cellW
                        width: 20 * Theme.cellW
                        elide: Text.ElideRight
                        visible: modelData.kind === "row"
                        color: Theme.fg
                        text: modelData.kind === "row" ? modelData.keys : ""
                    }

                    Txt {
                        x: 25 * Theme.cellW
                        width: 29 * Theme.cellW
                        elide: Text.ElideRight
                        visible: modelData.kind === "row"
                        color: Theme.dim
                        text: modelData.kind === "row" ? modelData.desc : ""
                    }
                }
            }

            Txt {
                y: (root.viewport + 2) * Theme.cellH
                color: Theme.dim
                text: "j/k scroll   g/G top/bottom   esc close"
            }
        }
    }
}
