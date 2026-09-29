import QtQuick

// A heater shield of arms (shaders/heraldry.frag), by default your own
// (War.arms: an ordinary argent on your tincture between charges Or). The
// shield fills the item, its point at the foot; a height of 1.2 times the
// width is a heater's usual build.
Item {
    id: arms

    property int ordinary: War.arms.ordinary
    property int charge: War.arms.charge
    property bool lone: false
    property color field: War.field
    property color metal: War.argent
    // On a chief the charges are of the field.
    property color chargeColor: ordinary === 7 ? field : War.or
    property color rimColor: War.steel
    property real rim: Math.max(1, width * 0.045)
    property real worn: 0.5
    property real glow: 0
    property color glowColor: War.fire
    property real seed: 1

    implicitWidth: 100
    implicitHeight: 120

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real ordinary: arms.ordinary
        property real charge: arms.charge
        property real lone: arms.lone ? 1 : 0
        property real rim: arms.rim
        property real worn: arms.worn
        property real glow: arms.glow
        property real seed: arms.seed
        property color fieldColor: arms.field
        property color metalColor: arms.metal
        property color chargeColor: arms.chargeColor
        property color rimColor: arms.rimColor
        property color glowColor: arms.glowColor

        fragmentShader: Qt.resolvedUrl("../../../../shaders/heraldry.frag.qsb")
    }
}
