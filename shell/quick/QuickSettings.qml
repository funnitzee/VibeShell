import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.services

// Quick settings panel: volume, Wi-Fi, Bluetooth and brightness in one TUI frame.
// Open with `Mod+S`, the `:qs` command, or by clicking the stats in the bar.
//   quickshell ipc -p <shell dir> call quick toggle
Scope {
    id: root

    property var pendingNetwork: null
    property string passText: ""

    function clearPending() {
        root.pendingNetwork = null;
        root.passText = "";
        pass.text = "";
    }

    // Signal strength as a 4-cell bar, strongest last.
    function strengthBars(network) {
        const s = Net.strength(network);
        const n = s >= 0.75 ? 4 : s >= 0.5 ? 3 : s >= 0.25 ? 2 : 1;
        return "▂▄▆█".slice(0, n).padEnd(4, " ");
    }

    function pickNetwork(network) {
        if (network.connected) {
            Net.disconnect();
            return;
        }
        if (Net.needsPassword(network)) {
            root.pendingNetwork = network;
            root.passText = "";
            pass.text = "";
            pass.forceActiveFocus();
            return;
        }
        Net.connect(network);
    }

    function submitPassword() {
        if (root.pendingNetwork === null)
            return;
        Net.connect(root.pendingNetwork, root.passText);
        root.clearPending();
    }

    // Small clickable action label, e.g. [ mute ] or [ on ].
    component Act: Txt {
        id: act
        signal activated
        property bool active: false
        color: active ? Theme.accent : Theme.fg
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: act.activated()
        }
    }

    // Gauge you can click to set a value. Emits the clicked fraction (0-1).
    component ClickBar: Item {
        id: bar
        property real value: 0
        property int size: 12
        signal valueSet(real fraction)
        implicitWidth: (size + 2) * Theme.cellW
        implicitHeight: Theme.cellH
        Gauge {
            anchors.fill: parent
            value: bar.value
            size: bar.size
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.valueSet(Math.max(0, Math.min(1, mouseX / width)))
        }
    }

    IpcHandler {
        target: "quick"

        function toggle(): void {
            Ui.toggleQuick();
        }
        function open(): void {
            Ui.openQuick();
        }
        function hide(): void {
            Ui.closeQuick();
        }
    }

    PanelWindow {
        id: win

        readonly property int cols: 54
        readonly property int rows: 18

        visible: Ui.quickOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "vibeshell-quick"

        anchors {
            top: true
            right: true
        }
        margins {
            top: Theme.gap * 3 + Theme.barHeight
            right: Theme.gap * 3
        }

        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight

        onVisibleChanged: {
            if (visible) {
                Net.scan(true);
                if (Bluetooth.enabled)
                    Bluetooth.setDiscovering(true);
                frame.forceActiveFocus();
            } else {
                Net.scan(false);
                if (Bluetooth.available)
                    Bluetooth.setDiscovering(false);
                root.clearPending();
            }
        }

        TuiFrame {
            id: frame

            cols: win.cols
            rows: win.rows
            title: "quick settings"
            color: Theme.dim
            dividers: [2, 9, 14]

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (root.pendingNetwork !== null)
                        root.clearPending();
                    else
                        Ui.closeQuick();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Q && root.pendingNetwork === null) {
                    Ui.closeQuick();
                    event.accepted = true;
                }
            }

            // -- volume --------------------------------------------------------
            Item {
                width: parent.width
                height: Theme.cellH
                visible: Audio.available

                Txt {
                    text: "vol "
                    color: Theme.dim
                }

                ClickBar {
                    x: 5 * Theme.cellW
                    value: Audio.percent
                    onValueSet: fraction => Audio.setVolume(fraction * 100)
                }

                Txt {
                    x: 20 * Theme.cellW
                    text: Audio.muted ? "muted" : `${Audio.percent}%`
                }

                Act {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.cellW
                    active: Audio.muted
                    text: Audio.muted ? "[ unmute ]" : "[  mute  ]"
                    onActivated: Audio.toggleMute()
                }
            }

            // -- wifi ----------------------------------------------------------
            Item {
                y: 2 * Theme.cellH
                width: parent.width
                height: Theme.cellH

                Txt {
                    text: "wifi "
                    color: Theme.dim
                }

                Txt {
                    x: 6 * Theme.cellW
                    text: !Net.wifiAvailable ? "no wi-fi" : Net.wifiEnabled ? "● on" : "○ off"
                    color: Net.wifiEnabled ? Theme.accent : Theme.dim
                }

                Txt {
                    x: 13 * Theme.cellW
                    width: 26 * Theme.cellW
                    elide: Text.ElideRight
                    text: {
                        const i = Net.info;
                        return i && i.kind === "wifi" ? i.name : "";
                    }
                }

                Act {
                    visible: Net.wifiAvailable
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.cellW
                    active: Net.wifiEnabled
                    text: Net.wifiEnabled ? "[ on ]" : "[ off ]"
                    onActivated: Net.setWifiEnabled(!Net.wifiEnabled)
                }
            }

            Repeater {
                model: Net.wifiAvailable && Net.wifiEnabled ? Net.wifiNetworks.slice(0, 5) : []

                delegate: Item {
                    required property var modelData
                    required property int index

                    y: (3 + index) * Theme.cellH
                    width: parent.width
                    height: Theme.cellH

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickNetwork(modelData)
                    }

                    Txt {
                        x: Theme.cellW
                        text: root.strengthBars(modelData)
                        color: Theme.dim
                    }

                    Txt {
                        x: 5 * Theme.cellW
                        width: 30 * Theme.cellW
                        elide: Text.ElideRight
                        color: modelData.connected ? Theme.accent : Theme.fg
                        text: modelData.name
                    }

                    Txt {
                        x: 36 * Theme.cellW
                        text: Net.needsPassword(modelData) ? "*" : " "
                        color: Theme.dim
                    }
                }
            }

            // -- bluetooth -----------------------------------------------------
            Item {
                y: 9 * Theme.cellH
                width: parent.width
                height: Theme.cellH

                Txt {
                    text: "bt   "
                    color: Theme.dim
                }

                Txt {
                    x: 6 * Theme.cellW
                    text: !Bluetooth.available ? "no adapter" : Bluetooth.enabled ? "● on" : "○ off"
                    color: Bluetooth.enabled ? Theme.accent : Theme.dim
                }

                Act {
                    visible: Bluetooth.available
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.cellW
                    active: Bluetooth.enabled
                    text: Bluetooth.enabled ? "[ on ]" : "[ off ]"
                    onActivated: Bluetooth.setEnabled(!Bluetooth.enabled)
                }
            }

            Repeater {
                model: Bluetooth.available && Bluetooth.enabled ? Bluetooth.devices.slice(0, 3) : []

                delegate: Item {
                    required property var modelData
                    required property int index

                    y: (10 + index) * Theme.cellH
                    width: parent.width
                    height: Theme.cellH

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bluetooth.toggleDevice(modelData)
                    }

                    Txt {
                        x: Theme.cellW
                        width: 34 * Theme.cellW
                        elide: Text.ElideRight
                        color: modelData.connected ? Theme.accent : Theme.fg
                        text: modelData.name !== "" ? modelData.name : modelData.address
                    }

                    Txt {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.cellW
                        color: Theme.dim
                        text: {
                            const b = Bluetooth.battery(modelData);
                            return (b < 0 ? "" : `${Math.round(b * 100)}%`) + (modelData.connected ? " ●" : "");
                        }
                    }
                }
            }

            // -- brightness ----------------------------------------------------
            Item {
                y: 14 * Theme.cellH
                width: parent.width
                height: Theme.cellH
                visible: Brightness.available

                Txt {
                    text: "bri  "
                    color: Theme.dim
                }

                ClickBar {
                    x: 5 * Theme.cellW
                    value: Brightness.percent
                    onValueSet: fraction => Brightness.setPercent(fraction * 100)
                }

                Txt {
                    x: 20 * Theme.cellW
                    text: `${Brightness.percent}%`
                }
            }

            // -- wifi password prompt ------------------------------------------
            Item {
                y: 15 * Theme.cellH
                width: parent.width
                height: Theme.cellH
                visible: root.pendingNetwork !== null

                Txt {
                    text: "pass "
                    color: Theme.dim
                }

                TextInput {
                    id: pass

                    x: 6 * Theme.cellW
                    width: 34 * Theme.cellW
                    height: Theme.cellH
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    onTextChanged: root.passText = text
                    onAccepted: root.submitPassword()
                }

                Act {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.cellW
                    active: true
                    text: "[ enter ]"
                    onActivated: root.submitPassword()
                }
            }
        }
    }
}
