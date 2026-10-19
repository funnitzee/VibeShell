import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.components
import qs.services

// StatusNotifier tray: one text token per app indicator, sitting left of the
// stats cluster. Left click activates, middle click runs the secondary action,
// the wheel scrolls (e.g. volume mixers) and a right click opens the item's
// menu when it has one.
Item {
    id: root

    readonly property var entries: TrayItems.items
    visible: entries.length > 0
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        spacing: Theme.cellW * 2

        Repeater {
            model: root.entries

            delegate: TrayEntry {
                required property var modelData
                item: modelData
            }
        }
    }

    component TrayEntry: Item {
        id: entry

        required property var item

        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight

        readonly property string text: {
            const title = (entry.item.title ?? "").trim();
            if (title.length > 0)
                return title.length > 12 ? title.slice(0, 11) + "…" : title;
            const id = (entry.item.id ?? "").split(".").pop();
            return id.length > 0 ? id : "•";
        }

        Txt {
            id: label
            anchors.centerIn: parent
            text: entry.text
            color: mouse.containsMouse ? Theme.accent : Theme.fg
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.MiddleButton) {
                    entry.item.secondaryActivate();
                } else if (event.button === Qt.RightButton) {
                    if (entry.item.hasMenu)
                        menu.open();
                    else
                        entry.item.secondaryActivate();
                } else if (entry.item.onlyMenu) {
                    menu.open();
                } else {
                    entry.item.activate();
                }
            }

            onWheel: event => entry.item.scroll(event.angleDelta.y, event.angleDelta.x !== 0)
        }

        QsMenuAnchor {
            id: menu
            anchor.item: entry
            menu: entry.item ? entry.item.menu : null
        }
    }
}
