pragma Singleton

import Quickshell
import QtQuick
import qs
import qs.services

// Search and execution backend of the command palette.
//   plain text  -> applications (fuzzy match)
//   :command    -> commands, e.g. ":ws 3" or ":set bar.gap 12"
// A result is { title, desc, insert, run }. run() returns { close, message }.
Singleton {
    id: root

    readonly property int maxResults: 10

    // Lower is better, -1 means no match.
    function score(text, query) {
        const t = text.toLowerCase();
        const q = query.toLowerCase();
        if (t === q)
            return 0;
        if (t.startsWith(q))
            return 1;
        if (t.includes(q))
            return 2;
        let i = 0;
        for (const c of t)
            if (c === q[i])
                i++;
        return i === q.length ? 3 : -1;
    }

    function parseValue(raw) {
        try {
            return JSON.parse(raw);
        } catch (e) {
            return raw;
        }
    }

    function launch(entry) {
        if (entry.runInTerminal)
            Quickshell.execDetached([Settings.data.apps.terminal, "-e"].concat(Array.from(entry.command)));
        else
            entry.execute();
    }

    readonly property var commands: [
        {
            name: "ws",
            usage: "<n>",
            desc: "focus workspace",
            run: args => {
                if (!/^\d+$/.test(args[0] ?? ""))
                    return {
                        close: false,
                        message: "usage: :ws <n>"
                    };
                Niri.focusWorkspace(Number(args[0]));
                return {
                    close: true
                };
            }
        },
        {
            name: "set",
            usage: "<key> <value>",
            desc: "change a setting live, e.g. bar.gap 12",
            run: args => {
                if (args.length < 2)
                    return {
                        close: false,
                        message: "usage: :set <key> <value>   e.g. :set bar.gap 12"
                    };
                const raw = args.slice(1).join(" ");
                const err = Settings.set(args[0], parseValue(raw));
                return {
                    close: false,
                    message: err !== "" ? err : `${args[0]} = ${raw}`
                };
            }
        },
        {
            name: "dash",
            usage: "",
            desc: "toggle the dashboard",
            run: () => {
                Ui.toggle();
                return {
                    close: true
                };
            }
        },
        {
            name: "qs",
            usage: "",
            desc: "toggle the quick settings panel",
            run: () => {
                Ui.toggleQuick();
                return {
                    close: true
                };
            }
        },
        {
            name: "settings",
            usage: "",
            desc: "toggle the settings window",
            run: () => {
                Ui.toggleSettings();
                return {
                    close: true
                };
            }
        },
        {
            name: "notify",
            usage: "",
            desc: "dismiss all notifications",
            run: () => {
                Notifications.clear();
                return {
                    close: true
                };
            }
        },
        {
            name: "lock",
            usage: "",
            desc: "lock the screen",
            run: () => {
                Lock.lock();
                return {
                    close: true
                };
            }
        },
        {
            name: "theming",
            usage: "",
            desc: "regenerate app theme files",
            run: () => {
                AppTheming.regenerate();
                return {
                    close: true,
                    message: `app themes -> ${AppTheming.outDir}`
                };
            }
        },
        {
            name: "theme",
            usage: "[name|next]",
            desc: "switch the color palette",
            run: args => {
                const list = Theme.palettes;
                if (args.length === 0)
                    return {
                        close: false,
                        message: `palette: ${Settings.data.theme.palette}   try: ${list.join(" ")}`
                    };
                let name = args[0];
                if (name === "next")
                    name = list[(list.indexOf(Settings.data.theme.palette) + 1) % list.length];
                if (!list.includes(name))
                    return {
                        close: false,
                        message: `unknown palette: ${name}`
                    };
                const err = Settings.set("theme.palette", name);
                return {
                    close: false,
                    message: err !== "" ? err : `theme.palette = ${name}`
                };
            }
        },
        {
            name: "term",
            usage: "",
            desc: "open a terminal",
            run: () => {
                Quickshell.execDetached([Settings.data.apps.terminal]);
                return {
                    close: true
                };
            }
        },
        {
            name: "reload",
            usage: "",
            desc: "reload the shell",
            run: () => {
                Quickshell.reload(false);
                return {
                    close: true
                };
            }
        }
    ]

    function searchCommands(rest) {
        const parts = rest.trim().split(/\s+/).filter(s => s.length > 0);
        const name = parts[0] ?? "";
        const args = parts.slice(1);
        const matches = commands.filter(c => c.name.startsWith(name));
        const exact = matches.find(c => c.name === name);
        const typingArgs = args.length > 0 || /\s$/.test(rest);

        const toResult = c => ({
                title: ":" + c.name + (c.usage !== "" ? " " + c.usage : ""),
                desc: c.desc,
                insert: ":" + c.name + (c.usage !== "" ? " " : ""),
                run: () => c.run(args)
            });

        if (exact && (typingArgs || matches.length === 1))
            return [toResult(exact)];
        return matches.map(toResult);
    }

    function searchApps(query) {
        const q = query.trim();
        if (q === "")
            return [];

        const hits = [];
        for (const e of DesktopEntries.applications.values) {
            let s = score(e.name, q);
            if (s < 0) {
                const extra = score(e.genericName + " " + Array.from(e.keywords).join(" "), q);
                if (extra >= 0)
                    s = extra + 10;
            }
            if (s >= 0)
                hits.push({
                    e,
                    s
                });
        }
        hits.sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name));

        return hits.slice(0, maxResults).map(h => ({
                    title: h.e.name,
                    desc: h.e.genericName || h.e.comment,
                    insert: h.e.name,
                    run: () => {
                        launch(h.e);
                        return {
                            close: true
                        };
                    }
                }));
    }

    function search(query) {
        return query.startsWith(":") ? searchCommands(query.slice(1)) : searchApps(query);
    }
}
