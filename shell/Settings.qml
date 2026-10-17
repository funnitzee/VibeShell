pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shipped defaults merged with the user's settings.json.
// The user file lives in $VIBESHELL_CONFIG_DIR or ~/.config/vibeshell.
Singleton {
    id: root

    readonly property string userDir: Quickshell.env("VIBESHELL_CONFIG_DIR") || (Quickshell.env("HOME") + "/.config/vibeshell")

    // Loaded synchronously so that bindings never see an empty object.
    readonly property var defaults: parse(defaultsFile.text())
    property var user: ({})
    readonly property var data: merge(defaults, user)

    function merge(base, over) {
        const out = {};
        for (const k in base)
            out[k] = base[k];
        for (const k in over) {
            const isObj = v => v !== null && typeof v === "object" && !Array.isArray(v);
            out[k] = isObj(over[k]) && isObj(out[k]) ? merge(out[k], over[k]) : over[k];
        }
        return out;
    }

    function get(obj, path) {
        let o = obj;
        for (const k of path.split(".")) {
            if (o === null || typeof o !== "object" || !(k in o))
                return undefined;
            o = o[k];
        }
        return o;
    }

    // Sets a user setting by dotted path (e.g. "bar.gap") and saves it.
    // Returns "" on success, otherwise a message describing what is wrong.
    function set(path, value) {
        const current = get(defaults, path);
        if (current === undefined)
            return `unknown setting: ${path}`;
        if (typeof current === "object")
            return `${path} is a section, set one of its keys`;
        if (typeof current !== typeof value)
            return `${path} expects a ${typeof current}`;

        const next = JSON.parse(JSON.stringify(user));
        const keys = path.split(".");
        let o = next;
        for (const k of keys.slice(0, -1)) {
            if (o[k] === null || typeof o[k] !== "object")
                o[k] = {};
            o = o[k];
        }
        o[keys[keys.length - 1]] = value;

        user = next;
        userFile.setText(JSON.stringify(next, null, 2) + "\n");
        return "";
    }

    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("VibeShell: invalid JSON in settings:", e);
            return {};
        }
    }

    FileView {
        id: defaultsFile
        path: Qt.resolvedUrl("defaults/settings.json")
        blockLoading: true
    }

    FileView {
        id: userFile
        path: root.userDir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.user = root.parse(text())
        onLoadFailed: root.user = ({})
        onSaveFailed: error => console.warn("VibeShell: could not save settings:", error)
    }
}
