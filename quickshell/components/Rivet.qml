import QtQuick

// A steel rivet head for Wasteland's bolted plates: lit from above, with a
// dark rim where it sits in the metal.
Rectangle {
    property real size: 4

    width: size
    height: size
    radius: size / 2
    border.width: size >= 6 ? 1 : 0.5
    border.color: "#15120e"
    gradient: Gradient {
        GradientStop { position: 0; color: "#b3ab9c" }
        GradientStop { position: 0.55; color: "#6e685e" }
        GradientStop { position: 1; color: "#34302a" }
    }
}
