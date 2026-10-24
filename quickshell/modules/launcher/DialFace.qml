pragma ComponentBehavior: Bound
import QtQuick

// The face of the launcher's wheel and its pointer, in the desktop theme's
// own object: a game's selection wheel, a tape reel, an orrery, a raked
// garden, a luopan, a neon sign, an ensō, an elevator's dial, a rose window,
// a rotary telephone, a valve's handwheel, an astrolabe, a sonar scope, the
// Konark wheel, a war shield, a tsuba. Only the theme's own face is built.
Item {
    id: root

    required property LauncherDial dial

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            "": plain,
            hud: hud,
            terminal: reel,
            cosmos: orrery,
            zen: garden,
            xianxia: luopan,
            cyberpunk: neon,
            wabisabi: enso,
            artdeco: sunburst,
            gothic: rose,
            newspaper: phone,
            wasteland: valve,
            observatory: astrolabe,
            abyss: sonar,
            devaloka: konark,
            siege: shield,
            sekiro: tsuba
        })[root.dial.themeId] ?? plain
    }

    Component {
        id: plain
        PlainFace {
            dial: root.dial
        }
    }

    Component {
        id: hud
        HudFace {
            dial: root.dial
        }
    }

    Component {
        id: reel
        ReelFace {
            dial: root.dial
        }
    }

    Component {
        id: orrery
        OrreryFace {
            dial: root.dial
        }
    }

    Component {
        id: garden
        GardenFace {
            dial: root.dial
        }
    }

    Component {
        id: luopan
        LuopanFace {
            dial: root.dial
        }
    }

    Component {
        id: neon
        NeonFace {
            dial: root.dial
        }
    }

    Component {
        id: enso
        EnsoFace {
            dial: root.dial
        }
    }

    Component {
        id: sunburst
        SunburstFace {
            dial: root.dial
        }
    }

    Component {
        id: rose
        RoseFace {
            dial: root.dial
        }
    }

    Component {
        id: phone
        PhoneFace {
            dial: root.dial
        }
    }

    Component {
        id: valve
        ValveFace {
            dial: root.dial
        }
    }

    Component {
        id: astrolabe
        AstrolabeFace {
            dial: root.dial
        }
    }

    Component {
        id: sonar
        SonarFace {
            dial: root.dial
        }
    }

    Component {
        id: konark
        KonarkFace {
            dial: root.dial
        }
    }

    Component {
        id: shield
        ShieldFace {
            dial: root.dial
        }
    }

    Component {
        id: tsuba
        TsubaFace {
            dial: root.dial
        }
    }
}
