import QtQuick

// One page's stock (shaders/book_paper.frag): the theme's paper, its grain
// and fibres, the gutter's shadow on the binding side and, on old stock,
// aged edges. `spineSide` is 0 for a left-hand page, 1 for a right-hand one.
// Drawn once into a layer and kept: the noise isn't run again each frame
// something else on the page moves.
ShaderEffect {
    id: paperFx

    layer.enabled: true

    property real spineSide: 0
    property real seed: 1

    property color paper: BookStyle.paper
    property color shade: BookStyle.shade
    readonly property real itemWidth: width
    readonly property real itemHeight: height
    property real grain: BookStyle.b.grain ?? 0.4
    property real fibres: BookStyle.b.fibres ?? 0.3
    property real age: BookStyle.b.age ?? 0
    property real gutter: BookStyle.lightPaper ? 1 : 0.85
    readonly property color ink: BookStyle.ink
    property real pattern: ({ dots: 1, scanlines: 2, stars: 3, rain: 4, sonar: 5 })[BookStyle.b.pattern ?? ""] ?? 0

    fragmentShader: Qt.resolvedUrl("../../shaders/book_paper.frag.qsb")
}
