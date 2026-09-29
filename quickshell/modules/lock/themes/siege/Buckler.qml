import QtQuick

// A buckler as a clock face (shaders/buckler.frag), the Siege clock's:
// painted gyronny in the tincture inside a riveted steel rim, a rivet on
// each hour, the quarter the watch is in lit by firelight, a sword for
// the hour hand and a spear for the minutes. It fills the item; its shadow
// spills a little past it.
Item {
    id: buckler

    // Local time.
    property real hour: 12
    property real minute: 0

    ShaderEffect {
        anchors.centerIn: parent
        width: Math.min(buckler.width, buckler.height) * inset
        height: width

        property real inset: 1.12
        property real itemWidth: width
        property real itemHeight: height
        property real hour: buckler.hour
        property real minute: buckler.minute
        property color fieldColor: War.field
        property color steelColor: Qt.tint(War.steel, "#20ffffff")
        property color goldColor: War.or
        property color fireColor: War.fire

        fragmentShader: Qt.resolvedUrl("../../../../shaders/buckler.frag.qsb")
    }
}
