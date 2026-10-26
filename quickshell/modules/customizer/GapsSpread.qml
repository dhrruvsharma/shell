pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter IV, § 1: Hyprland's gaps, the windows' borders and corners, and
// the layout they're tiled in. Each is the theme's (or hypr/hyprland.lua's)
// until it's set here, and can go back to that.
Spread {
    id: spread

    readonly property var wl: Services.WindowLook

    Component.onCompleted: spread.wl.refresh()

    leftContent: Plate {
        chapter: 4
        title: "Windows"
        epigraph: "How they sit together on the screen, and how they're cut."
        figure: "Fig. 7."
        caption: ({
            "general.gaps_in": "The gap between two windows: each keeps this much to itself.",
            "general.gaps_out": "The gap between the windows and the screen's edges (and the bar).",
            "general.border_size": "The border round each window, lit on the focused one.",
            "decoration.rounding": "The radius of a window's corners.",
            "decoration.rounding_power": "The shape of the corners: a circle's arc at 2, a squircle's at 4 and above.",
            "general.layout": "How windows are tiled."
        })[spread.focusKey] ?? "The screen as your windows are tiled, and a detail where they meet under the bar."

        GapsFigure {
            anchors.fill: parent
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Gaps, borders and corners"
        intro: "Set here, they go over what the desktop theme or your Hyprland config has, and stay through theme changes and reloads. The undo mark beside one gives it back."
        spacing: 20

        LookSlider {
            key: "general.gaps_in"
            label: "Between windows"
            unit: "px"
        }

        LookSlider {
            key: "general.gaps_out"
            label: "To the screen's edges"
            unit: "px"
        }

        LookSlider {
            key: "general.border_size"
            label: "Border"
            unit: "px"
        }

        LookSlider {
            key: "decoration.rounding"
            label: "Corner radius"
            unit: "px"
        }

        LookSlider {
            key: "decoration.rounding_power"
            label: "Corner shape"
            note: "2 is round; 4 and up, a squircle."
            stepSize: 0.1
            decimals: 1
        }

        Entry {
            width: parent.width
            key: "general.layout"
            label: "Layout"
            note: "How new windows are placed."
            overridden: spread.wl.has("general.layout")
            resetText: "config's"
            onReset: spread.wl.clear("general.layout")

            InkChoice {
                options: [{ id: "dwindle", label: "Dwindle" }, { id: "master", label: "Master" }, { id: "scrolling", label: "Scrolling" }]
                current: spread.wl.value("general.layout") ?? ""
                spacing: 14
                onChosen: id => spread.wl.set("general.layout", id)
            }
        }

        InkButton {
            visible: spread.wl.count > 0
            icon: "undo"
            text: "Give every one back"
            quiet: true
            onClicked: spread.wl.clearAll()
        }
    }

    // One of Hyprland's numbers: a slider, the theme's (or the config's)
    // value marked on it, and the way back to it once it's set here.
    component LookSlider: Entry {
        id: ls

        property real stepSize: 1
        property int decimals: 0
        property string unit: ""
        readonly property var opt: spread.wl.options[ls.key]

        width: parent ? parent.width : 0
        controlWidth: 300
        overridden: spread.wl.has(ls.key)
        resetText: Services.DesktopTheme.enabled ? "theme's" : "config's"
        onReset: spread.wl.clear(ls.key)

        InkSlider {
            from: ls.opt.min
            to: ls.opt.max
            stepSize: ls.stepSize
            decimals: ls.decimals
            unit: ls.unit
            value: Number(spread.wl.value(ls.key) ?? ls.opt.min)
            mark: spread.wl.has(ls.key) ? Number(spread.wl.base[ls.key] ?? NaN) : NaN
            onMoved: v => spread.wl.set(ls.key, v)
        }
    }
}
