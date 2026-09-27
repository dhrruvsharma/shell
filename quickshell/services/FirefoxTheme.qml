pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import qs.colors

// Firefox in the rice's look. Writes three stylesheets into the default
// profile's chrome/ folder, which its userChrome.css and userContent.css
// @import:
//   quickshell-colors.css   the wallpaper colours (from Colors)
//   quickshell-theme.css    firefox/chrome.css + the desktop theme's firefox/<id>.css
//   quickshell-content.css  firefox/content.css (new tab, settings, add-ons)
// Firefox reads them when it starts, so changes show on its next launch.
// Only the main shell sets `manage`.
Singleton {
    id: root

    property bool manage: false
    // The default profile's chrome/ folder ("" until found, or no Firefox).
    property string chromeDir: ""
    readonly property string sourceDir: Quickshell.shellPath("firefox")
    readonly property string theme: DesktopTheme.enabled ? DesktopTheme.theme : ""

    property var _written: ({})

    function _write(name, text) {
        if (!chromeDir || _written[name] === text)
            return;
        const view = name === "colors" ? colorsOut : name === "theme" ? themeOut : contentOut;
        view.setText(text);
        const w = Object.assign({}, _written);
        w[name] = text;
        _written = w;
    }

    function _colors() {
        const roles = {
            "bg": Colors.background, "surface": Colors.surface_container, "surface-low": Colors.surface_container_low,
            "surface-high": Colors.surface_container_high, "surface-highest": Colors.surface_container_highest,
            "fg": Colors.on_surface, "fg-dim": Colors.on_surface_variant, "primary": Colors.primary,
            "on-primary": Colors.on_primary, "primary-container": Colors.primary_container,
            "on-primary-container": Colors.on_primary_container, "tertiary": Colors.tertiary,
            "on-tertiary": Colors.on_tertiary, "outline": Colors.outline, "outline-variant": Colors.outline_variant,
            "error": Colors.error
        };
        let css = "/* Wallpaper colours for Firefox, written by Quickshell (services/FirefoxTheme.qml). */\n:root {\n";
        for (const k in roles)
            css += "  --qs-" + k + ": " + roles[k] + ";\n";
        return css + "}\n";
    }

    function sync() {
        if (!manage || !chromeDir || !baseChrome.ready || !baseContent.ready)
            return;
        _write("colors", _colors());
        _write("theme", baseChrome.text() + (theme && themeCss.ready ? "\n" + themeCss.text() : ""));
        _write("content", baseContent.text());
    }

    Timer {
        id: syncTimer
        interval: 400
        onTriggered: root.sync()
    }

    onManageChanged: syncTimer.restart()
    onChromeDirChanged: syncTimer.restart()
    onThemeChanged: syncTimer.restart()

    Connections {
        target: Colors

        function onBackgroundChanged() {
            syncTimer.restart();
        }

        function onPrimaryChanged() {
            syncTimer.restart();
        }

        function onTertiaryChanged() {
            syncTimer.restart();
        }
    }

    // The profile Firefox starts with: the install's Default=, else the
    // profile marked Default=1.
    Process {
        running: root.manage
        command: ["sh", "-c", "for d in \"$HOME/.config/mozilla/firefox\" \"$HOME/.mozilla/firefox\"; do [ -f \"$d/profiles.ini\" ] && { echo \"$d\"; cat \"$d/profiles.ini\"; exit 0; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const dir = lines.shift().trim();
                if (!dir)
                    return;
                let installDefault = "";
                let section = "";
                let profile = {};
                const profiles = [];
                for (const raw of lines) {
                    const l = raw.trim();
                    if (l.startsWith("[")) {
                        section = l;
                        profile = {};
                        if (l.startsWith("[Profile"))
                            profiles.push(profile);
                        continue;
                    }
                    const eq = l.indexOf("=");
                    if (eq < 0)
                        continue;
                    const key = l.substring(0, eq);
                    const value = l.substring(eq + 1);
                    if (section.startsWith("[Install") && key === "Default")
                        installDefault = value;
                    else if (section.startsWith("[Profile"))
                        profile[key] = value;
                }
                const chosen = installDefault ? { Path: installDefault, IsRelative: installDefault.startsWith("/") ? "0" : "1" }
                    : profiles.find(p => p.Default === "1") ?? profiles[0];
                if (chosen && chosen.Path)
                    root.chromeDir = (chosen.IsRelative === "1" ? dir + "/" + chosen.Path : chosen.Path) + "/chrome";
            }
        }
    }

    component Source: FileView {
        property bool ready: false
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            ready = true;
            syncTimer.restart();
        }
        onLoadFailed: {
            ready = false;
            syncTimer.restart();
        }
    }

    Source {
        id: baseChrome
        path: root.sourceDir + "/chrome.css"
    }

    Source {
        id: baseContent
        path: root.sourceDir + "/content.css"
    }

    Source {
        id: themeCss
        path: root.theme ? root.sourceDir + "/" + root.theme + ".css" : ""
        onPathChanged: ready = false
    }

    component Output: FileView {
        blockWrites: true
        printErrors: false
    }

    Output {
        id: colorsOut
        path: root.chromeDir ? root.chromeDir + "/quickshell-colors.css" : ""
    }

    Output {
        id: themeOut
        path: root.chromeDir ? root.chromeDir + "/quickshell-theme.css" : ""
    }

    Output {
        id: contentOut
        path: root.chromeDir ? root.chromeDir + "/quickshell-content.css" : ""
    }
}
