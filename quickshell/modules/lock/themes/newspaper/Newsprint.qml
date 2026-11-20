import QtQuick

// A sheet of newsprint (shaders/newsprint.frag, pass 0): fill the sheet's
// rect with it and set the print on top. Grey-cream stock with its fibres,
// specks and cloudy formation, the back of the page showing through, edges
// yellowed by `age`, cut in short straight snips that don't run quite
// square to the print (or `torn`), and a shadow that hugs it where it lies
// flat and opens out under a corner that curls up (`lift`). A NewsprintInk
// over the print gives the same sheet's ink, light, creases and tape.
//
// It draws Press.bleed px past its rect all round, so whatever surface it's
// in needs that much room. Static: drawn once into a layer, again only when
// its size or a setting changes.
Item {
    id: sheet

    // Each sheet its own: where it was cut, what's on its back.
    property real seed: 1
    property color paper: Press.paper
    property color shade: Press.paperAged
    property real age: 0.4
    // The back of the page showing through, 0..1.
    property real show: 1
    // Creases: down the sheet at this fraction across, across it at this
    // fraction down (< 0: none).
    property real foldX: -1
    property real foldY: -1
    // A curled corner, 0..1, and which (0 top left, clockwise).
    property real lift: 0
    property int liftCorner: 2
    // Which edges are torn rather than cut (left, top, right, bottom; 0..1).
    property vector4d torn: Qt.vector4d(0, 0, 0, 0)
    // How far a snip strays, and a cut's ends from square, px.
    property real wobble: 1
    property real skew: 1.5
    property real shadow: 1
    // Tape: 0 none, 1 a strip over the top edge, 2 across both top corners,
    // 3 the top left one, 4 the top right one.
    property int tape: 0

    // 0 the paper, 1 what goes over the print (NewsprintInk).
    property int pass: 0

    ShaderEffect {
        x: -Press.bleed
        y: -Press.bleed
        width: sheet.width + 2 * Press.bleed
        height: sheet.height + 2 * Press.bleed
        visible: sheet.width > 0 && sheet.height > 0

        layer.enabled: true
        layer.smooth: true
        // (for the theme previews, which show it scaled right down)
        layer.mipmap: true

        readonly property real itemWidth: width
        readonly property real itemHeight: height
        readonly property real bleed: Press.bleed
        readonly property real pass: sheet.pass
        readonly property real seed: sheet.seed
        readonly property color paper: sheet.paper
        readonly property color shade: sheet.shade
        readonly property color ink: Press.ink
        readonly property real age: sheet.age
        readonly property real show: sheet.show
        readonly property real foldX: sheet.foldX
        readonly property real foldY: sheet.foldY
        readonly property real lift: sheet.lift
        readonly property real liftCorner: sheet.liftCorner
        readonly property vector4d torn: sheet.torn
        readonly property real wobble: sheet.wobble
        readonly property real skew: sheet.skew
        readonly property real shadow: sheet.shadow
        readonly property real tape: sheet.tape

        fragmentShader: Qt.resolvedUrl("../../../../shaders/newsprint.frag.qsb")
    }
}
