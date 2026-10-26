pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter IV, § 2: how solid the windows are, the blur behind them, the
// shadow they cast, dimming the ones you're not in, and Hyprland's
// animations. Like § 1, each is the theme's or the config's until set here.
Spread {
    id: spread

    readonly property var wl: Services.WindowLook
    readonly property string back: Services.DesktopTheme.enabled ? "theme's" : "config's"

    function flag(key) {
        return !!spread.wl.value(key);
    }

    Component.onCompleted: spread.wl.refresh()

    leftContent: Plate {
        chapter: 4
        title: "Windows"
        opening: false
        section: "Glass and shadow"
        figure: "Fig. 8."
        caption: "The window you're in, over one you're not: what shows through each, the blur, the shadow, the dimming."

        GlassFigure {
            anchors.fill: parent
            anchors.margins: 2
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 2"
        title: "Glass and shadow"
        intro: "How solid the windows are, and what happens to what's behind them."
        spacing: 13

        Percent {
            key: "decoration.active_opacity"
            label: "The window you're in"
        }

        Percent {
            key: "decoration.inactive_opacity"
            label: "The others"
        }

        Toggle {
            key: "decoration.dim_inactive"
            label: "Dim the others"
        }

        Percent {
            key: "decoration.dim_strength"
            label: "Dimmed by"
            dim: !spread.flag("decoration.dim_inactive")
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Toggle {
            key: "decoration.blur.enabled"
            label: "Blur behind windows"
        }

        Amount {
            key: "decoration.blur.size"
            label: "Its size"
            dim: !spread.flag("decoration.blur.enabled")
        }

        Amount {
            key: "decoration.blur.passes"
            label: "Its passes"
            dim: !spread.flag("decoration.blur.enabled")
        }

        Percent {
            key: "decoration.blur.vibrancy"
            label: "Vibrancy"
            dim: !spread.flag("decoration.blur.enabled")
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Toggle {
            key: "decoration.shadow.enabled"
            label: "Shadows"
        }

        Amount {
            key: "decoration.shadow.range"
            label: "Their reach"
            unit: "px"
            dim: !spread.flag("decoration.shadow.enabled")
        }

        Amount {
            key: "decoration.shadow.render_power"
            label: "Their falloff"
            dim: !spread.flag("decoration.shadow.enabled")
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Toggle {
            key: "animations.enabled"
            label: "Animations"
        }
    }

    component Toggle: Entry {
        id: t

        width: parent ? parent.width : 0
        overridden: spread.wl.has(t.key)
        resetText: spread.back
        onReset: spread.wl.clear(t.key)

        InkSwitch {
            checked: spread.flag(t.key)
            onToggled: spread.wl.set(t.key, !spread.flag(t.key))
        }
    }

    component Amount: Entry {
        id: n

        property string unit: ""
        readonly property var opt: spread.wl.options[n.key]

        width: parent ? parent.width : 0
        controlWidth: 290
        overridden: spread.wl.has(n.key)
        resetText: spread.back
        onReset: spread.wl.clear(n.key)

        InkSlider {
            from: n.opt.min
            to: n.opt.max
            stepSize: 1
            unit: n.unit
            value: Number(spread.wl.value(n.key) ?? n.opt.min)
            mark: spread.wl.has(n.key) ? Number(spread.wl.base[n.key] ?? NaN) : NaN
            onMoved: v => spread.wl.set(n.key, v)
        }
    }

    component Percent: Entry {
        id: p

        readonly property var opt: spread.wl.options[p.key]

        width: parent ? parent.width : 0
        controlWidth: 290
        overridden: spread.wl.has(p.key)
        resetText: spread.back
        onReset: spread.wl.clear(p.key)

        InkSlider {
            from: Math.round(p.opt.min * 100)
            to: Math.round(p.opt.max * 100)
            stepSize: 1
            unit: "%"
            value: Math.round(Number(spread.wl.value(p.key) ?? p.opt.max) * 100)
            mark: spread.wl.has(p.key) ? Math.round(Number(spread.wl.base[p.key] ?? NaN) * 100) : NaN
            onMoved: v => spread.wl.set(p.key, v / 100)
        }
    }
}
