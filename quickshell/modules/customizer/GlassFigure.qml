pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.colors
import qs.services as Services

// The plate for the windows' glass: a window you're in, floating over one
// you're not, on your wallpaper, as Hyprland would draw them with the
// settings in force: how much of what's behind shows through each, blurred
// or not (how much: the blur's size and passes), the shadow the focused one
// casts, and the others dimmed. The part pointed at opposite is named.
Item {
    id: fig

    property string lit: ""

    readonly property var wl: Services.WindowLook
    function num(key, fallback) {
        const v = fig.wl.value(key);
        return v === undefined || v === null ? fallback : Number(v);
    }
    function on(key, fallback) {
        const v = fig.wl.value(key);
        return v === undefined || v === null ? fallback : !!v;
    }

    readonly property real activeOpacity: fig.num("decoration.active_opacity", 1)
    readonly property real inactiveOpacity: fig.num("decoration.inactive_opacity", 1)
    readonly property bool blur: fig.on("decoration.blur.enabled", true)
    readonly property real blurSize: fig.num("decoration.blur.size", 8)
    readonly property real blurPasses: fig.num("decoration.blur.passes", 1)
    readonly property real vibrancy: fig.num("decoration.blur.vibrancy", 0.17)
    readonly property bool shadow: fig.on("decoration.shadow.enabled", true)
    readonly property real shadowRange: fig.num("decoration.shadow.range", 4)
    readonly property real shadowPower: fig.num("decoration.shadow.render_power", 3)
    readonly property bool dim: fig.on("decoration.dim_inactive", false)
    readonly property real dimStrength: fig.num("decoration.dim_strength", 0.5)
    readonly property real rounding: fig.num("decoration.rounding", 10)
    readonly property real zoom: 0.5
    readonly property real r: fig.rounding * fig.zoom

    // The wallpaper, and the window that isn't focused: what the focused
    // one is seen over.
    Item {
        id: backdrop
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Pane {
            id: back
            x: parent.width * 0.06
            y: parent.height * 0.08
            width: parent.width * 0.56
            height: parent.height * 0.62
            fillOpacity: fig.inactiveOpacity
            focused: false

            Rectangle {
                anchors.fill: parent
                radius: fig.r
                color: "#000000"
                opacity: fig.dim ? fig.dimStrength : 0
            }
        }
    }

    // The focused window's shadow.
    RectangularShadow {
        anchors.fill: front
        visible: fig.shadow && fig.shadowRange > 0
        radius: fig.r
        blur: fig.shadowRange * fig.zoom * 1.6
        spread: 0
        // A higher power falls off sooner.
        color: Colors.withAlpha("#000000", 0.85 / Math.max(1, fig.shadowPower * 0.6))
    }

    // What shows through the focused window: the backdrop, blurred.
    Item {
        id: through
        anchors.fill: front
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: frontMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        ShaderEffectSource {
            x: -front.x
            y: -front.y
            width: fig.width
            height: fig.height
            sourceItem: backdrop
            live: true
            layer.enabled: fig.blur
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: Math.min(64, Math.round(fig.blurSize * Math.sqrt(fig.blurPasses) * 2.2))
                saturation: fig.vibrancy * 0.6
            }
        }
    }

    Rectangle {
        id: frontMask
        width: front.width
        height: front.height
        radius: fig.r
        visible: false
        layer.enabled: true
    }

    Pane {
        id: front
        x: parent.width * 0.38
        y: parent.height * 0.3
        width: parent.width * 0.52
        height: parent.height * 0.56
        fillOpacity: fig.activeOpacity
        focused: true
    }

    // Names for what's pointed at.
    Rectangle {
        visible: tag.text !== ""
        x: Math.min(parent.width - width - 8, front.x + 12)
        y: front.y + front.height + 10
        width: tag.implicitWidth + 16
        height: 24
        radius: 4
        color: BookStyle.paper
        border.width: 1
        border.color: BookStyle.accent

        BookText {
            id: tag
            anchors.centerIn: parent
            text: ({
                "decoration.active_opacity": "focused: " + Math.round(fig.activeOpacity * 100) + "% solid",
                "decoration.inactive_opacity": "behind: " + Math.round(fig.inactiveOpacity * 100) + "% solid",
                "decoration.blur.enabled": fig.blur ? "blurred behind" : "seen clear through",
                "decoration.blur.size": "blur " + fig.blurSize + " × " + fig.blurPasses,
                "decoration.blur.passes": "blur " + fig.blurSize + " × " + fig.blurPasses,
                "decoration.blur.vibrancy": "vibrancy " + Math.round(fig.vibrancy * 100) + "%",
                "decoration.shadow.enabled": fig.shadow ? "a shadow under it" : "no shadow",
                "decoration.shadow.range": "shadow " + fig.shadowRange + " px",
                "decoration.shadow.render_power": "shadow falls off at " + fig.shadowPower,
                "decoration.dim_inactive": fig.dim ? "the other dimmed" : "the other as it is",
                "decoration.dim_strength": "dimmed by " + Math.round(fig.dimStrength * 100) + "%"
            })[fig.lit] ?? ""
            font.pixelSize: 12
            font.italic: true
            color: BookStyle.accent
        }
    }

    // A window: its fill (as solid as set), a bar of a title and a few lines.
    component Pane: Item {
        id: w

        property real fillOpacity: 1
        property bool focused: false

        Rectangle {
            anchors.fill: parent
            radius: fig.r
            color: Colors.withAlpha(Colors.surface_container_low, w.fillOpacity)
            border.width: Math.max(1, Number(fig.wl.value("general.border_size") ?? 2) * fig.zoom)
            border.color: w.focused ? Colors.primary : Colors.withAlpha(Colors.outline, 0.7)
        }

        Column {
            x: Math.max(14, fig.r)
            y: Math.max(12, fig.r * 0.7)
            spacing: 11
            opacity: w.focused ? 0.75 : 0.5

            Repeater {
                model: 6

                Rectangle {
                    required property int index
                    width: (w.width - 2 * Math.max(14, fig.r)) * (index === 0 ? 0.35 : 0.5 + 0.45 * ((index * 7) % 10) / 10)
                    height: index === 0 ? 8 : 5
                    radius: height / 2
                    color: index === 0 ? Colors.primary : Colors.on_surface
                    opacity: index === 0 ? 0.85 : 0.4
                }
            }
        }
    }
}
