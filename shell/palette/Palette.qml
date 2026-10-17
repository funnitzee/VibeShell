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
            root.open = !root.open;
        }
        function open(query: string): void {
            root.initialQuery = query;
            root.open = true;
        }
        function hide(): void {
            root.open = false;
        }
        // Runs the best result of a query without showing the palette, e.g. `call palette run ":ws 2"`.
        function run(query: string): string {
            const r = Commands.search(query)[0];
            if (!r)
                return "no match";
            return (r.run() ?? {}).message ?? "";
        }
    }

    PanelWindow {
        id: win

        readonly property int cols: 72
        // top border, input, divider, results, divider, status, bottom border
        readonly property int rows: Commands.maxResults + 6

        property int selected: 0
        property string message: ""
        readonly property var results: Commands.search(input.text)

        function move(delta) {
            if (results.length > 0)
                selected = (selected + delta + results.length) % results.length;
        }

        function complete() {
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
            title: "vibeshell"
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
                    if (event.key === Qt.Key_Escape)
                        root.open = false;
                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J)))
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
                text: win.message !== "" ? win.message : "enter run   tab complete   esc close   : commands"
                color: win.message !== "" ? Theme.fg : Theme.dim
            }
        }
    }
}
