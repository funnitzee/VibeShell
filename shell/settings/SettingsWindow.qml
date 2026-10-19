import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// TUI settings window: lists every setting from defaults, edit in place and it
// saves to ~/.config/vibeshell/settings.json (the shell reloads on save).
// Open with `Mod+Shift+S`, the `:settings` command, or over IPC:
//   quickshell ipc -p <shell dir> call settings toggle
Scope {
    id: root

    property int cursor: 0
    property bool editing: false
    property string status: ""

    // A live, non-persistent row appended to the list when the tool is present.
    readonly property string powerPath: "@power-profile"

    // Keys walked from the shipped defaults, so the list stays in sync.
    readonly property var rows: {
        const base = leaves(Settings.defaults, "");
        return PowerProfiles.available ? base.concat([{
                path: root.powerPath,
                type: "choice"
            }]) : base;
    }
    readonly property int rowCount: rows.length
    readonly property var current: cursor >= 0 && cursor < rows.length ? rows[cursor] : null

    // Per-key edit step and floor for numbers.
    readonly property var numberSpec: ({
            "font.size": {
                step: 1,
                min: 6
            },
            "ui.scale": {
                step: 0.1,
                min: 0.5
            },
            "stats.interval": {
                step: 100,
                min: 100
            },
            "notify.timeout": {
                step: 1,
                min: 1
            },
            "notify.max": {
                step: 1,
                min: 1
            },
            "idle.lock": {
                step: 30,
                min: 0
            },
            "idle.screenOff": {
                step: 30,
                min: 0
            },
            "bar.height": {
                step: 1,
                min: 10
            },
            "bar.gap": {
                step: 1,
                min: 0
            },
            "bar.radius": {
                step: 1,
                min: 0
            },
            "bar.borderWidth": {
                step: 1,
                min: 0
            },
            "notify.historyMax": {
                step: 5,
                min: 0
            },
            "night.temperature": {
                step: 250,
                min: 1000
            },
            "power.lowThreshold": {
                step: 5,
                min: 0
            }
        })

    function leaves(obj, prefix) {
        const out = [];
        for (const k in obj) {
            const v = obj[k];
            const path = prefix ? prefix + "." + k : k;
            if (v !== null && typeof v === "object" && !Array.isArray(v))
                out.push.apply(out, leaves(v, path));
            else
                out.push({
                    path: path,
                    type: typeof v
                });
        }
        return out;
    }

    function valueOf(row) {
        return Settings.get(Settings.data, row.path);
    }

    function display(row) {
        if (row.path === root.powerPath)
            return PowerProfiles.active !== "" ? PowerProfiles.active : "-";
        const v = valueOf(row);
        if (v === undefined)
            return undefined;
        if (typeof v === "boolean")
            return v ? "on" : "off";
        return String(v);
    }

    function move(delta) {
        root.status = "";
        root.cursor = (root.cursor + delta + root.rowCount) % root.rowCount;
    }

    function step(direction) {
        const row = root.current;
        if (row === null)
            return;
        root.status = "";

        if (row.path === root.powerPath) {
            const list = PowerProfiles.profiles;
            if (list.length === 0)
                return;
            const at = list.indexOf(PowerProfiles.active);
            PowerProfiles.set(list[(at + direction + list.length) % list.length]);
            return;
        }

        if (row.path === "theme.palette") {
            const list = Theme.palettes;
            const at = list.indexOf(Settings.data.theme.palette);
            const next = list[(at + direction + list.length) % list.length];
            commit("theme.palette", next);
            return;
        }

        if (row.type === "boolean") {
            commit(row.path, !valueOf(row));
            return;
        }

        if (row.type !== "number")
            return;
        const spec = root.numberSpec[row.path] ?? {
            step: 1,
            min: 0
        };
        const next = Math.max(spec.min, valueOf(row) + direction * spec.step);
        commit(row.path, next);
    }

    function startEdit() {
        const row = root.current;
        if (row === null || row.path === "theme.palette" || row.path === root.powerPath)
            return; // palettes and profiles are cycled, not typed
        if (row.type === "boolean") {
            // Booleans have no free text, so Enter just toggles them.
            commit(row.path, !valueOf(row));
            return;
        }
        editor.text = display(row);
        root.editing = true;
        editor.forceActiveFocus();
    }

    function cancelEdit() {
        root.editing = false;
        frame.forceActiveFocus();
    }

    function commitEdit() {
        const row = root.current;
        const raw = editor.text;
        root.editing = false;
        frame.forceActiveFocus();
        if (row === null)
            return;
        if (row.type === "number") {
            const spec = root.numberSpec[row.path] ?? {
                step: 1,
                min: 0
            };
            const n = Number(raw);
            if (raw.trim() === "" || Number.isNaN(n)) {
                root.status = `not a number: ${raw}`;
                return;
            }
            // Integer steps round; float steps (e.g. ui.scale) keep the value.
            const val = spec.step >= 1 ? Math.round(n) : Math.round(n * 100) / 100;
            commit(row.path, Math.max(spec.min, val));
        } else {
            commit(row.path, raw);
        }
    }

    function commit(path, value) {
        const err = Settings.set(path, value);
        if (err !== "")
            root.status = err;
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            Ui.toggleSettings();
        }
        function open(): void {
            Ui.openSettings();
        }
        function hide(): void {
            Ui.closeSettings();
        }
    }

    PanelWindow {
        id: win

        readonly property int cols: 58
        // Room for the header, every setting row and the hint line.
        readonly property int rows: root.rowCount + 6

        screen: Niri.focusedScreen
        visible: Ui.settingsOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-settings"

        // Only the top edge is anchored, so niri centers the window horizontally.
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
                root.status = "";
                frame.forceActiveFocus();
            } else {
                root.editing = false;
            }
        }

        TuiFrame {
            id: frame

            cols: win.cols
            rows: win.rows
            title: "settings"
            color: Theme.dim
            dividers: [2]

            Keys.onPressed: event => {
                if (root.editing) {
                    if (event.key === Qt.Key_Escape) {
                        root.cancelEdit();
                        event.accepted = true;
                    }
                    return;
                }
                switch (event.key) {
                case Qt.Key_Escape:
                case Qt.Key_Q:
                    Ui.closeSettings();
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                case Qt.Key_J:
                    root.move(1);
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                case Qt.Key_K:
                    root.move(-1);
                    event.accepted = true;
                    break;
                case Qt.Key_Right:
                case Qt.Key_L:
                case Qt.Key_Plus:
                case Qt.Key_Equal:
                    root.step(1);
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                case Qt.Key_H:
                case Qt.Key_Minus:
                    root.step(-1);
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_E:
                    root.startEdit();
                    event.accepted = true;
                    break;
                case Qt.Key_G:
                    root.status = "";
                    root.cursor = event.modifiers & Qt.ShiftModifier ? root.rowCount - 1 : 0;
                    event.accepted = true;
                    break;
                }
            }

            // Header
            Txt {
                x: 2 * Theme.cellW
                text: "setting"
                color: Theme.dim
            }

            Txt {
                x: 27 * Theme.cellW
                text: "value"
                color: Theme.dim
            }

            // One selectable row per setting.
            Repeater {
                model: root.rows

                delegate: Item {
                    required property var modelData
                    required property int index

                    readonly property bool selected: root.cursor === index

                    y: (2 + index) * Theme.cellH
                    width: parent.width
                    height: Theme.cellH

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.cursor === index && !root.editing)
                                root.startEdit();
                            else
                                root.cursor = index;
                        }
                    }

                    Txt {
                        text: selected ? "> " : "  "
                        color: Theme.accent
                    }

                    Txt {
                        x: 2 * Theme.cellW
                        width: 24 * Theme.cellW
                        elide: Text.ElideRight
                        color: selected ? Theme.accent : Theme.dim
                        text: modelData.path
                    }

                    Txt {
                        x: 27 * Theme.cellW
                        width: 28 * Theme.cellW
                        elide: Text.ElideRight
                        visible: !(selected && root.editing)
                        color: selected ? Theme.accent : Theme.fg
                        text: root.display(modelData)
                    }
                }
            }

            // Single editor, drawn over the selected row while editing.
            TextInput {
                id: editor

                visible: root.editing
                x: 27 * Theme.cellW
                y: (2 + root.cursor) * Theme.cellH
                width: 28 * Theme.cellW
                height: Theme.cellH
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                selectionColor: Theme.accent
                selectedTextColor: Theme.bg
                onAccepted: root.commitEdit()
            }

            // Hint / last error.
            Txt {
                y: (root.rowCount + 3) * Theme.cellH
                color: root.status !== "" ? Theme.urgent : Theme.dim
                text: root.status !== "" ? root.status : "j/k move   h/l change   g/G top/bottom   enter edit   esc close"
            }
        }
    }
}
