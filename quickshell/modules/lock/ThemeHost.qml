pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services
// Themes are loaded by URL (services/LockScreen.qml), which Quickshell's
// module scanner never follows, so their folders would get no synthesized
// qmldir. Quickshell serves the config over a "network" scheme, and without
// a qmldir Qt fetches sibling types one by one, racing the synchronous load:
// a theme then fails at random with "X is not a type". These imports only
// make the scanner visit the folders; nothing from them is used here. (URL
// loading stays, so a broken theme falls back instead of breaking the lock.)
import qs.modules.lock.themes.arcade as ArcadeTheme
import qs.modules.lock.themes.cosmos as CosmosTheme
import qs.modules.lock.themes.terminal as TerminalTheme
import qs.modules.lock.themes.xianxia as XianxiaTheme
import qs.modules.lock.themes.zen as ZenTheme

// Loads a lock theme's surface (see services/LockScreen.qml) and hands it the
// shared context. A theme that fails to load falls back to the default theme,
// then to FallbackSurface: whatever a theme file does, the lock always ends
// up with a way to type the password.
Item {
    id: host

    required property LockContext ctx
    property string themeId: Services.LockScreen.defaultTheme
    property url shot
    property bool shown: true
    // Thumbnail mode: fully assembled, no intro, no input.
    property bool still: false
    property real minScale: 0.7

    readonly property var theme: Services.LockScreen.theme(themeId)
    readonly property string loadedId: _loadedId
    readonly property bool failed: _failed

    property string _loadedId: ""
    property bool _failed: false
    property bool _completed: false

    function load() {
        const props = {
            ctx: host.ctx,
            shot: host.shot,
            shown: host.shown,
            still: host.still,
            minScale: host.minScale
        };
        const candidates = [host.theme, Services.LockScreen.theme(Services.LockScreen.defaultTheme)];
        for (let i = 0; i < candidates.length; i++) {
            const t = candidates[i];
            if (i > 0 && t.id === candidates[0].id)
                break;
            loader.setSource(t.source, props);
            if (loader.status === Loader.Ready && loader.item !== null) {
                _loadedId = t.id;
                _failed = false;
                return;
            }
            console.warn("lock: theme", t.id, "failed to load");
        }
        loader.source = "";
        _loadedId = "";
        _failed = true;
    }

    onThemeIdChanged: if (_completed) load()
    Component.onCompleted: {
        _completed = true;
        load();
    }

    Loader {
        id: loader
        anchors.fill: parent
        asynchronous: false
    }

    Binding {
        target: loader.item
        property: "shown"
        value: host.shown
        when: loader.item !== null
    }

    Loader {
        anchors.fill: parent
        active: host._failed
        sourceComponent: FallbackSurface {
            ctx: host.ctx
            still: host.still
        }
    }
}
