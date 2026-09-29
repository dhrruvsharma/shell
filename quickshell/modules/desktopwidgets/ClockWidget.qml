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
        sourceComponent: ({ hud: hud, terminal: terminal, cosmos: cosmos, zen: zen, xianxia: xianxia, cyberpunk: neon, wabisabi: wabi, artdeco: deco, gothic: gothic, newspaper: broadsheet, wasteland: wasteland, observatory: observatory, abyss: abyss, devaloka: devaloka, siege: siege })[root.themeId] ?? plain
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
        id: neon
        NeonClock { now: clock.date }
    }

    Component {
        id: wabi
        WabiClock { now: clock.date }
    }

    Component {
        id: deco
        DecoClock { now: clock.date }
    }

    Component {
        id: gothic
        GothicClock { now: clock.date }
    }

    Component {
        id: broadsheet
        BroadsheetClock { now: clock.date }
    }

    Component {
        id: wasteland
        WastelandClock { now: clock.date }
    }

    Component {
        id: observatory
        ObservatoryClock { now: clock.date }
    }

    Component {
        id: abyss
        AbyssClock { now: clock.date }
    }

    Component {
        id: devaloka
        DevalokaClock { now: clock.date }
    }

    Component {
        id: siege
        SiegeClock { now: clock.date }
    }

    Component {
        id: plain
        PlainClock { now: clock.date }
    }
}
