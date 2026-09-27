pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services as Services

// Desktop clock: the face of the desktop theme (or the plain one), redrawn
// once a minute.
Item {
    id: root

    property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Loader {
        id: face
        sourceComponent: ({ hud: hud, terminal: terminal, cosmos: cosmos, zen: zen, xianxia: xianxia })[root.themeId] ?? plain
    }

    Component {
        id: hud
        HudClock { now: clock.date }
    }

    Component {
        id: terminal
        TerminalClock { now: clock.date }
    }

    Component {
        id: cosmos
        CosmosClock { now: clock.date }
    }

    Component {
        id: zen
        ZenClock { now: clock.date }
    }

    Component {
        id: xianxia
        XianxiaClock { now: clock.date }
    }

    Component {
        id: plain
        PlainClock { now: clock.date }
    }
}
