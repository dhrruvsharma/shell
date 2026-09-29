pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services as Services

// One desktop theme's layer (<Name>Layer.qml), picked by `themeId`: drawn
// over the wallpaper (modules/wallpaper/WallpaperLayer), or scaled down as a
// preview in the Themes panel (`still`, `pxScale`). Every layer takes the
// same properties: boot (0..1, its switch-on choreography), now (a minute
// clock) and pxScale (screen pixels per layer pixel, so shader detail and
// hairlines stay visible in a small preview). A layer that reworks the
// wallpaper itself (Broadsheet prints it in halftone, Abyss sinks it under
// water; `usesWallpaper`) also takes `wallpaper`: a texture provider of
// what's under the layer, the same size. Clocks and the rest are desktop
// widgets (modules/desktopwidgets).
Item {
    id: root

    property string themeId: Services.DesktopTheme.theme
    property bool still: false
    property real pxScale: 1
    property real boot: still ? 1 : 0
    property Item wallpaper: null
    readonly property bool usesWallpaper: themeId === "newspaper" || themeId === "abyss"

    readonly property var components: ({
        hud: hudLayer,
        terminal: terminalLayer,
        cosmos: cosmosLayer,
        zen: zenLayer,
        xianxia: xianxiaLayer,
        cyberpunk: neonLayer,
        wabisabi: wabiLayer,
        artdeco: decoLayer,
        gothic: gothicLayer,
        newspaper: broadsheetLayer,
        wasteland: wastelandLayer,
        observatory: observatoryLayer,
        abyss: abyssLayer,
        devaloka: devalokaLayer,
        siege: siegeLayer
    })

    onThemeIdChanged: replay()
    Component.onCompleted: replay()

    function replay() {
        if (still)
            return;
        bootAnim.restart();
    }

    NumberAnimation {
        id: bootAnim
        target: root
        property: "boot"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.OutCubic
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.components[root.themeId] ?? null
    }

    Component {
        id: hudLayer
        HudLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: terminalLayer
        TerminalLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: cosmosLayer
        CosmosLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: zenLayer
        ZenLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: xianxiaLayer
        XianxiaLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: neonLayer
        NeonLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: wabiLayer
        WabiLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: decoLayer
        DecoLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: gothicLayer
        GothicLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: broadsheetLayer
        BroadsheetLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
            wallpaper: root.wallpaper
        }
    }

    Component {
        id: wastelandLayer
        WastelandLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: observatoryLayer
        ObservatoryLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: devalokaLayer
        DevalokaLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: siegeLayer
        SiegeLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
        }
    }

    Component {
        id: abyssLayer
        AbyssLayer {
            boot: root.boot
            now: clock.date
            pxScale: root.pxScale
            wallpaper: root.wallpaper
        }
    }
}
