import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components

// Vim-style command palette: plain text launches apps, ":" starts a command.
// Open it with `quickshell ipc -p <shell> call palette toggle` (bound to Mod+; by the installer).
Scope {
    id: root

    property bool open: false
    property string initialQuery: ""

    IpcHandler {
        target: "palette"

        function toggle(): void {
            if (!root.open)
                win.exitList();
            root.open = !root.open;
        }
        function open(query: string): void {
            win.exitList();
            root.initialQuery = query;
            root.open = true;
        }
        function hide(): void {
            root.open = false;
        }
        // Runs the best result of a query. A command that returns a picker (e.g.
        // `run ":emoji"`) opens the palette straight into list mode, so list
        // commands are reachable from keybinds and scripts too.
        function run(query: string): string {
            const r = Commands.search(query)[0];
            if (!r)
                return "no match";
            const out = r.run() ?? {};
            if (out.list) {
                win.listName = out.title ?? "";
                win.listItems = out.list;
                win.selected = 0;
                root.initialQuery = "";
                root.open = true;
                return `list:${out.list.length}`;
            }
            return out.message ?? "";
        }
    }

    PanelWindow {
        id: win

        readonly property int cols: 72
        readonly property int maxRows: 12

        // List mode: a command can return { list, title } to turn the palette
        // into a picker (clipboard, emoji, power, help). Typing filters it and
        // Esc drops back to the command prompt.
        property var listItems: null
        property string listName: ""
        readonly property bool listMode: listItems !== null

        // top border, input, divider, results, divider, status, bottom border
        readonly property int rows: (listMode ? Math.min(Math.max(listItems.length, 1), maxRows) : Commands.maxResults) + 6

        property int selected: 0
        property string message: ""

        readonly property var results: {
            if (!listMode)
                return Commands.search(input.text);
            const q = input.text.trim();
            const shown = q === "" ? listItems : listItems.filter(it => Commands.score(it.title, q) >= 0);
            return shown.slice(0, maxRows);
        }

        function exitList() {
            listItems = null;
            listName = "";
            selected = 0;
        }

        function move(delta) {
            if (results.length > 0)
                selected = (selected + delta + results.length) % results.length;
        }

        function complete() {
            if (listMode)
                return;
            const r = results[selected];
            if (!r)
                return;
            input.text = r.insert;
            input.cursorPosition = input.length;
        }

        function run() {
            const r = results[selected];
            if (!r)
                return;
            const out = r.run() ?? {};
            // A command can open a picker instead of acting directly.
            if (out.list) {
                message = "";
                listName = out.title ?? "";
                listItems = out.list;
                input.text = "";
                selected = 0;
                return;
            }
            // A list entry can drop text back into the prompt for editing.
            if (out.fill !== undefined) {
                input.text = out.fill;
                input.cursorPosition = input.length;
                return;
            }
            message = out.message ?? "";
            if (out.close ?? true)
                root.open = false;
        }

        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-palette"

        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        onVisibleChanged: {
            if (!visible)
                return;
            message = "";
            input.text = root.initialQuery;
            root.initialQuery = "";
            input.forceActiveFocus();
            input.cursorPosition = input.length;
        }

        TuiFrame {
            id: frame

            cols: win.cols
            rows: win.rows
            title: win.listMode ? win.listName : "vibeshell"
            color: Theme.dim
            dividers: [2, win.rows - 3]

            Txt {
                id: prompt
                text: "> "
                color: Theme.dim
            }

            TextInput {
                id: input

                x: prompt.width
                width: parent.width - prompt.width
                height: Theme.cellH
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectionColor: Theme.fg
                selectedTextColor: Theme.bg
                clip: true

                cursorDelegate: Rectangle {
                    width: Theme.cellW
                    color: Theme.fg

                    SequentialAnimation on opacity {
                        running: Theme.animations
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0
                            duration: 530
                        }
                        NumberAnimation {
                            to: 1
                            duration: 530
                        }
                    }
                }

                onTextChanged: {
                    win.selected = 0;
                    win.message = "";
                }
                onAccepted: win.run()

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape) {
                        if (win.listMode)
                            win.exitList();
                        else
                            root.open = false;
                    } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J)))
                        win.move(1);
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K)))
                        win.move(-1);
                    else if (event.key === Qt.Key_Tab)
                        win.complete();
                    else
                        event.accepted = false;
                }
            }

            Repeater {
                model: win.results

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === win.selected

                    y: (2 + index) * Theme.cellH
                    width: parent.width
                    height: Theme.cellH

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.fg
                        visible: row.current
                    }
                    Txt {
                        id: title
                        x: Theme.cellW / 2
                        text: row.modelData.title
                        color: row.current ? Theme.bg : Theme.fg
                    }
                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.cellW / 2
                        width: Math.min(implicitWidth, parent.width - title.width - Theme.cellW * 3)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: row.modelData.desc
                        color: row.current ? Theme.bg : Theme.dim
                    }
                }
            }

            Txt {
                y: (win.rows - 3) * Theme.cellH
                x: Theme.cellW / 2
                width: parent.width - Theme.cellW
                elide: Text.ElideRight
                text: win.message !== "" ? win.message : (win.listMode ? "enter select   type to filter   esc back" : "enter run   tab complete   esc close   : commands")
                color: win.message !== "" ? Theme.fg : Theme.dim
            }
        }
    }
}
