pragma ComponentBehavior: Bound
import QtQuick
import qs.components

// A plate of salvaged steel (shaders/scrap_plate.frag), rust blooming in
// from its edges, bolted on at the corners: what the Wasteland theme builds
// its widgets, readouts and lock screen fittings from. `seed` makes each
// one its own.
Item {
    id: plate

    property real seed: 1
    property real rust: 0.7
    property real fill: 0.92
    property bool rivets: true
    property real rivetSize: 6
    property real rivetInset: 8
    property color steel: Waste.steel

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real seed: plate.seed
        property real rust: plate.rust
        property real fill: plate.fill
        property real inset: plate.rivetInset
        property color steelColor: plate.steel
        property color rustColor: Waste.rust

        fragmentShader: Qt.resolvedUrl("../../../../shaders/scrap_plate.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Waste.alpha(Waste.grime, 0.85)
    }

    Repeater {
        model: plate.rivets ? 4 : 0

        Rivet {
            required property int index
            size: plate.rivetSize
            x: (index % 2 === 0 ? plate.rivetInset : plate.width - plate.rivetInset) - width / 2
            y: (index < 2 ? plate.rivetInset : plate.height - plate.rivetInset) - height / 2
        }
    }
}
