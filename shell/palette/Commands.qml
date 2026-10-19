pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.services

// Search and execution backend of the command palette.
//   plain text  -> applications (fuzzy match)
//   :command    -> commands, e.g. ":ws 3" or ":set bar.gap 12"
// A result is { title, desc, insert, run }. run() returns { close, message }.
//
// Users can drop executable scripts into ~/.config/vibeshell/commands (or
// $VIBESHELL_CONFIG_DIR/commands). They show up as :name; a line reading
// "# desc: something" gives the entry its description.
Singleton {
    id: root

    readonly property int maxResults: 10

    // -- user command plugins ------------------------------------------------
    property string pluginDir: Settings.userDir + "/commands"
    property var plugins: []

    readonly property var pluginCommands: plugins.map(p => ({
            name: p.name,
            usage: "[args]",
            desc: p.desc,
            run: args => {
                Quickshell.execDetached([p.path].concat(args));
                return {
                    close: true
                };
            }
        }))

    function scanPlugins() {
        if (!scan.running)
            scan.running = true;
    }

    Process {
        id: scan
        command: ["sh", "-c", `d="$1"; [ -d "$d" ] || exit 0; for f in "$d"/*; do [ -f "$f" ] && [ -x "$f" ] || continue; desc=$(sed -n 's/^# desc: //p' "$f" | head -n1); printf '%s\\t%s\\n' "$(basename "$f")" "$desc"; done`, "vibeshell", root.pluginDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line === "")
                        continue;
                    const parts = line.split("\t");
                    const file = parts[0];
                    if (!file)
                        continue;
                    out.push({
                        name: file.replace(/\.sh$/, ""),
                        path: root.pluginDir + "/" + file,
                        desc: parts[1] || "user command"
                    });
                }
                root.plugins = out;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.scanPlugins()
    }

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

    readonly property var builtin: [
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
            usage: "[dnd|history|clear]",
            desc: "notifications: dismiss, do-not-disturb, history",
            run: args => {
                const a = args[0];
                if (a === "dnd") {
                    Notifications.toggleDnd();
                    return {
                        close: false,
                        message: `do-not-disturb ${Settings.data.notify.dnd ? "on" : "off"}`
                    };
                }
                if (a === "clear") {
                    Notifications.clear();
                    return {
                        close: false,
                        message: "notifications dismissed"
                    };
                }
                if (a === "history" || a === "hist") {
                    const h = Notifications.history.slice().reverse();
                    if (h.length === 0)
                        return {
                            close: false,
                            message: "notification history is empty"
                        };
                    return {
                        close: false,
                        title: "history",
                        list: h.map(n => ({
                                title: n.summary || "(no summary)",
                                desc: `${n.app || "?"} · ${ago(n.time)}`.trim(),
                                run: () => ({
                                    close: true
                                })
                            }))
                    };
                }
                const h = Notifications.history.slice().reverse();
                return {
                    close: false,
                    title: "notifications",
                    list: [
                        {
                            title: "dismiss all",
                            desc: `${Notifications.all.length} on screen`,
                            run: () => {
                                Notifications.clear();
                                return { close: true };
                            }
                        },
                        {
                            title: Notifications.dnd ? "turn off do-not-disturb" : "do not disturb",
                            desc: "suppress popups (history still kept)",
                            run: () => {
                                Notifications.toggleDnd();
                                return { close: true };
                            }
                        },
                        {
                            title: "history",
                            desc: `${h.length} recent`,
                            run: () => root.byName("notify").run(["history"])
                        }
                    ]
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
            name: "wallpaper",
            usage: "[next|prev|<path>]",
            desc: "change the wallpaper (swww/swaybg)",
            run: args => {
                if (!Wallpaper.available)
                    return {
                        close: false,
                        message: "no wallpaper tool found (install swww or swaybg)"
                    };
                if (args.length === 0 || args[0] === "next")
                    Wallpaper.next();
                else if (args[0] === "prev")
                    Wallpaper.prev();
                else
                    Wallpaper.set(args.join(" "));
                return {
                    close: true
                };
            }
        },
        {
            name: "tile",
            usage: "[preset]",
            desc: "tiling presets: wide narrow mono center float max",
            run: args => {
                const presets = {
                    wide: ["set-column-width", "70%"],
                    narrow: ["set-column-width", "30%"],
                    mono: ["set-column-width", "100%"],
                    center: ["center-column"],
                    float: ["toggle-window-floating"],
                    max: ["maximize-column"],
                    normal: ["set-column-width", "50%"]
                };
                const p = presets[args[0]];
                if (!p)
                    return {
                        close: false,
                        message: `usage: :tile <${Object.keys(presets).join("|")}>`
                    };
                Niri.action(p[0], p.slice(1));
                return {
                    close: true
                };
            }
        },
        {
            name: "niri",
            usage: "<action> [args]",
            desc: "run any niri action, e.g. :niri consume-or-expel-window-right",
            run: args => {
                if (args.length === 0)
                    return {
                        close: false,
                        message: "usage: :niri <action> [args]   e.g. :niri center-column"
                    };
                Niri.action(args[0], args.slice(1));
                return {
                    close: true
                };
            }
        },
        {
            name: "anim",
            usage: "",
            desc: "toggle shell animations",
            run: () => {
                const next = !Settings.data.anim.enabled;
                const err = Settings.set("anim.enabled", next);
                return {
                    close: false,
                    message: err !== "" ? err : `animations ${next ? "on" : "off"}`
                };
            }
        },
        {
            name: "matugen",
            usage: "",
            desc: "sync app colors from the accent via matugen",
            run: () => {
                AppTheming.syncMatugen();
                return {
                    close: false,
                    message: `matugen: ${String(Theme.accent)}`
                };
            }
        },
        {
            name: "scale",
            usage: "<n>",
            desc: "UI scale, e.g. :scale 1.25",
            run: args => {
                const n = Number(args[0]);
                if (args.length === 0 || Number.isNaN(n) || n < 0.5 || n > 3)
                    return {
                        close: false,
                        message: "usage: :scale <0.5-3>"
                    };
                const err = Settings.set("ui.scale", Math.round(n * 100) / 100);
                return {
                    close: false,
                    message: err !== "" ? err : `ui.scale = ${n}`
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
            name: "power",
            usage: "[profile [name]]",
            desc: "power menu (lock/suspend/...) and CPU profiles",
            run: args => {
                if (args[0] === "profile" || args[0] === "pp") {
                    if (!PowerProfiles.available)
                        return {
                            close: false,
                            message: "power profiles need power-profiles-daemon"
                        };
                    if (args[1]) {
                        PowerProfiles.set(args[1]);
                        return {
                            close: false,
                            message: `power profile: ${args[1]}`
                        };
                    }
                    return {
                        close: false,
                        title: "power profile",
                        list: PowerProfiles.profiles.map(p => ({
                                title: p,
                                desc: p === PowerProfiles.active ? "active" : "",
                                run: () => {
                                    PowerProfiles.set(p);
                                    return {
                                        close: true,
                                        message: `power profile: ${p}`
                                    };
                                }
                            }))
                    };
                }
                return {
                    close: false,
                    title: "power",
                    list: [
                        {
                            title: "lock",
                            desc: "lock the screen",
                            run: () => {
                                Lock.lock();
                                return { close: true };
                            }
                        },
                        {
                            title: "suspend",
                            desc: "lock, then suspend to RAM",
                            run: () => {
                                Power.suspend();
                                return { close: true };
                            }
                        },
                        {
                            title: "logout",
                            desc: "end the niri session",
                            run: () => {
                                Power.logout();
                                return { close: true };
                            }
                        },
                        {
                            title: "reboot",
                            desc: "restart the machine",
                            run: () => {
                                Power.reboot();
                                return { close: true };
                            }
                        },
                        {
                            title: "shutdown",
                            desc: "power the machine off",
                            run: () => {
                                Power.shutdown();
                                return { close: true };
                            }
                        }
                    ]
                };
            }
        },
        {
            name: "night",
            usage: "[on|off|warmer|cooler|<kelvin>]",
            desc: "night light (warmer screen colours)",
            run: args => {
                if (!NightLight.available)
                    return {
                        close: false,
                        message: "night light needs gammastep, redshift or wlsunset"
                    };
                const a = args[0];
                if (a === undefined)
                    NightLight.toggle();
                else if (a === "on")
                    NightLight.set(true);
                else if (a === "off")
                    NightLight.set(false);
                else if (a === "warmer" || a === "+")
                    NightLight.adjust(-250);
                else if (a === "cooler" || a === "-")
                    NightLight.adjust(250);
                else if (/^\d+$/.test(a))
                    NightLight.setTemperature(Number(a));
                else
                    return {
                        close: false,
                        message: "usage: :night [on|off|warmer|cooler|<kelvin>]"
                    };
                return {
                    close: false,
                    message: `night light ${NightLight.enabled ? "on" : "off"} @ ${NightLight.temperature}K`
                };
            }
        },
        {
            name: "keys",
            usage: "",
            desc: "keybind cheatsheet",
            run: () => {
                Ui.toggleKeys();
                return {
                    close: true
                };
            }
        },
        {
            name: "shot",
            usage: "[full|region|edit|region-edit]",
            desc: "screenshot to ~/Pictures/Screenshots and the clipboard",
            run: args => {
                const modes = ["full", "region", "edit", "region-edit"];
                if (args.length > 0) {
                    if (!modes.includes(args[0]))
                        return {
                            close: false,
                            message: `usage: :shot <${modes.join("|")}>`
                        };
                    return Screenshot.capture(args[0]);
                }
                if (!Screenshot.available)
                    return {
                        close: false,
                        message: "screenshot needs grim (and slurp for region)"
                    };
                const list = [
                    {
                        title: "full",
                        desc: "the whole screen",
                        run: () => Screenshot.capture("full")
                    },
                    {
                        title: "region",
                        desc: "drag to select an area",
                        run: () => Screenshot.capture("region")
                    }
                ];
                if (Screenshot.canAnnotate) {
                    list.push({
                        title: "edit",
                        desc: "full screen, then annotate (swappy)",
                        run: () => Screenshot.capture("edit")
                    });
                    list.push({
                        title: "region-edit",
                        desc: "select an area, then annotate (swappy)",
                        run: () => Screenshot.capture("region-edit")
                    });
                }
                return {
                    close: false,
                    title: "screenshot",
                    list: list
                };
            }
        },
        {
            name: "clip",
            usage: "[clear]",
            desc: "clipboard history (cliphist)",
            run: args => {
                if (!Clipboard.available)
                    return {
                        close: false,
                        message: "clipboard history needs cliphist + wl-clipboard"
                    };
                if (args[0] === "clear") {
                    Clipboard.clear();
                    return {
                        close: false,
                        message: "clipboard history cleared"
                    };
                }
                Clipboard.refresh();
                if (Clipboard.entries.length === 0)
                    return {
                        close: false,
                        message: "clipboard history is empty"
                    };
                return {
                    close: false,
                    title: "clipboard",
                    list: Clipboard.entries.map(e => ({
                            title: e.preview,
                            desc: e.id,
                            run: () => {
                                Clipboard.copy(e.id);
                                return { close: true };
                            }
                        }))
                };
            }
        },
        {
            name: "emoji",
            usage: "",
            desc: "pick an emoji (copies it to the clipboard)",
            run: () => ({
                close: false,
                title: "emoji",
                list: Emoji.list.map(e => ({
                        title: `${e.char}  ${e.name}`,
                        desc: "",
                        run: () => {
                            Emoji.copy(e.char);
                            return {
                                close: true,
                                message: `copied ${e.char}`
                            };
                        }
                    }))
            })
        },
        {
            name: "help",
            usage: "",
            desc: "list all commands",
            run: () => ({
                close: false,
                title: "help",
                list: root.commands.map(c => ({
                        title: ":" + c.name + (c.usage !== "" ? " " + c.usage : ""),
                        desc: c.desc,
                        run: () => ({
                            close: false,
                            fill: ":" + c.name + (c.usage !== "" ? " " : "")
                        })
                    }))
            })
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

    // Built-in commands plus any user plugins, in that order.
    readonly property var commands: builtin.concat(pluginCommands)

    function byName(name) {
        return commands.find(c => c.name === name) ?? null;
    }

    // Short relative time ("3m", "2h", "4d") for the notification history.
    function ago(ms) {
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
        if (s < 60)
            return `${s}s ago`;
        if (s < 3600)
            return `${Math.round(s / 60)}m ago`;
        if (s < 86400)
            return `${Math.round(s / 3600)}h ago`;
        return `${Math.round(s / 86400)}d ago`;
    }

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
