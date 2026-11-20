pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter X, § 1: the panorama (services/Panorama). How a switch looks (the
// strip swinging round, Hyprland's own slide, or nothing at all), whether
// the swipe carries the strip, its pace, its bend and its depth, what's
// behind the cards, and which overview Alt + Tab brings.
Spread {
    id: spread

    readonly property var pano: Services.Panorama

    leftContent: Plate {
        chapter: 10
        title: "The Panorama"
        epigraph: "Your workspaces stand round you; a switch turns you to the next."
        figure: "Fig. 16."
        caption: {
            if (spread.focusKey === "view")
                return spread.pano.view === "panorama" ? "The overview: held drawn back, a card lit. Click the figure to see a switch." : "The overview is the grid of windows; this is how the panorama would hold it.";
            if (spread.pano.switching === "panorama")
                return "Half way through a switch, at the bend and depth set opposite. Click it to see one at the pace set.";
            return spread.pano.switching === "off" ? "Switches cut straight across; the strip only shows in the overview." : "Switches slide as Hyprland does; the strip only shows in the overview.";
        }

        PanoramaFigure {
            anchors.fill: parent
            anchors.margins: 2
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Between workspaces"
        intro: "Your workspaces as cards on a strip that bends round you. Switching swings it from one to the next: the screen draws back into its card, turns, and settles on the next."
        spacing: 14

        Entry {
            width: parent.width
            key: "switching"
            label: "As you switch"
            note: spread.pano.switching === "panorama"
                ? "Workspace keys, the scroll binds, the disc and the swipe swing the strip round. Hyprland's own slide is off meanwhile."
                : spread.pano.switching === "off"
                    ? "No animation at all: switches cut straight across. Alt + Tab still has the overview."
                    : "Hyprland's own workspace animation, as hyprland.lua sets it."
            stacked: true

            InkChoice {
                options: [{ id: "panorama", label: "The panorama" }, { id: "hyprland", label: "Hyprland's slide" }, { id: "off", label: "None" }]
                current: spread.pano.switching
                onChosen: id => spread.pano.set("switching", id)
            }
        }

        Entry {
            width: parent.width
            key: "gestures"
            label: "Follow your fingers"
            note: "The three-finger swipe carries the strip as you go, as far as Hyprland's swipe would."
            dim: !spread.pano.transitions

            InkSwitch {
                checked: spread.pano.gestures
                onToggled: spread.pano.set("gestures", !spread.pano.gestures)
            }
        }

        Entry {
            width: parent.width
            key: "duration"
            label: "Its pace"
            note: "How long a switch takes."
            controlWidth: 290
            dim: !spread.pano.transitions

            InkSlider {
                from: 300
                to: 1200
                stepSize: 25
                unit: "ms"
                value: spread.pano.duration
                onMoved: v => spread.pano.set("duration", v)
            }
        }

        Entry {
            width: parent.width
            key: "curve"
            label: "How far it bends"
            note: "From a flat strip to a ring all the way round you."
            controlWidth: 290

            InkSlider {
                from: 0
                to: 100
                stepSize: 5
                unit: "%"
                value: Math.round(spread.pano.curve * 100)
                onMoved: v => spread.pano.set("curve", v / 100)
            }
        }

        Entry {
            width: parent.width
            key: "depth"
            label: "How far it draws back"
            controlWidth: 290

            InkSlider {
                from: 15
                to: 70
                stepSize: 5
                unit: "%"
                value: Math.round(spread.pano.depth * 100)
                onMoved: v => spread.pano.set("depth", v / 100)
            }
        }

        Entry {
            width: parent.width
            key: "view"
            label: "The overview (Alt + Tab)"
            note: spread.pano.view === "panorama"
                ? "Turn it with the arrows, the wheel or a drag; Enter or a click goes there, Esc back. G for the grid."
                : "Every window live, to drag between workspaces. P for the panorama."
            stacked: true

            InkChoice {
                options: [{ id: "panorama", label: "The panorama" }, { id: "grid", label: "The grid" }]
                current: spread.pano.view
                onChosen: id => spread.pano.set("view", id)
            }
        }
    }
}
