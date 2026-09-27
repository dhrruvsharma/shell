pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

Item {
    id: root

    property int alignment: 0
    property int radius: 50
    property color color: Colors.background

    default property alias content: contentWrapper.data

    // Keeps the content inside the bubble while it grows/shrinks. This used to
    // be a 16x MSAA layer (twice, nested with BubbleShape's), which reallocated
    // two multisampled offscreen buffers on every frame of an open/close
    // animation. A clip is just a scissor rect; the shape antialiases itself.
    clip: true

    readonly property real _halfW: root.width * 0.5
    readonly property real _halfH: root.height * 0.5
    readonly property real _thirdH: root.height / 3
    readonly property real _r: root.radius
    readonly property real _r2: root.radius * 2
    readonly property real _clampedRW: Math.min(root._r, root._halfW)
    readonly property real _clampedRH: Math.min(root._r, root._halfH)
    readonly property real _clampedRH3: Math.min(root._r, root._thirdH)

    // Square desktop themes (HUD, Mainframe, Cave Abode) swap the bubble for
    // a box in their style. Round themes keep the bubble.
    readonly property bool themed: Services.DesktopTheme.controlRadius >= 0
    // The bubble's body runs the full depth of the popout and is inset by
    // the radius only at the ends of the edge(s) it's attached to (where the
    // flares are); the box covers exactly that.
    readonly property bool _insetLeft: [0, 4, 1, 3].includes(root.alignment)
    readonly property bool _insetRight: [0, 4, 5, 7].includes(root.alignment)
    readonly property bool _insetTop: [2, 6, 3, 5].includes(root.alignment)
    readonly property bool _insetBottom: [2, 6, 1, 7].includes(root.alignment)

    Rectangle {
        visible: root.themed
        x: root._insetLeft ? root.radius : 0
        y: root._insetTop ? root.radius : 0
        width: root.width - x - (root._insetRight ? root.radius : 0)
        height: root.height - y - (root._insetBottom ? root.radius : 0)
        radius: Services.DesktopTheme.panelRadius(root.radius)
        color: root.color

        PanelDecor {
            radius: parent.radius
        }
    }

    Loader {
        anchors.fill: parent
        asynchronous: true
        visible: !root.themed

        sourceComponent: {
            const shapes = [attachedTop, attachedTopRight, attachedRight, attachedBottomRight, attachedBottom, attachedBottomLeft, attachedLeft, attachedTopLeft];
            return root.alignment >= 0 && root.alignment < 8 ? shapes[root.alignment] : null;
        }
    }

    Item {
        id: contentWrapper
        anchors.fill: parent
        anchors.margins: root.radius
    }

    component BubbleShape: Shape {
        anchors.fill: parent
        // The curve renderer antialiases edges in its shader, so no MSAA
        // layer is needed for smooth corners.
        preferredRendererType: Shape.CurveRenderer

        default property alias pathElements: shapePath.pathElements

        ShapePath {
            id: shapePath
            fillColor: root.color
            // This outline thing still isn't ready yet.. [very unstable like rendering issues].
            strokeColor: Colors.background
            strokeWidth: -1
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
        }
    }

    Component {
        id: attachedTop
        BubbleShape {
            id: topShape
            PathMove {
                x: 0
                y: 0
            }
            PathArc {
                x: root._r
                y: root._clampedRH
                radiusX: root._r
                radiusY: root._clampedRH
            }
            PathLine {
                x: root._r
                y: Math.max(topShape.height - root._r, root._halfH)
            }
            PathArc {
                x: root._r2
                y: topShape.height
                radiusX: root._r
                radiusY: root._clampedRH
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: topShape.width - root._r2
                y: topShape.height
            }
            PathArc {
                x: topShape.width - root._r
                y: Math.max(topShape.height - root._r, root._halfH)
                radiusX: root._r
                radiusY: root._clampedRH
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: topShape.width - root._r
                y: root._clampedRH
            }
            PathArc {
                x: topShape.width
                y: 0
                radiusX: root._r
                radiusY: root._clampedRH
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Component {
        id: attachedTopRight
        BubbleShape {
            id: topRightShape
            PathMove {
                x: 0
                y: 0
            }
            PathArc {
                x: root._r
                y: root._clampedRH3
                radiusX: root._r
                radiusY: root._clampedRH3
            }
            PathLine {
                x: root._r
                y: Math.max(topRightShape.height - root._r2, root._thirdH)
            }
            PathArc {
                x: root._r2
                y: Math.max(topRightShape.height - root._r, 2 * root._thirdH)
                radiusX: root._r
                radiusY: root._clampedRH3
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: topRightShape.width - root._r
                y: Math.max(topRightShape.height - root._r, 2 * root._thirdH)
            }
            PathArc {
                x: topRightShape.width
                y: topRightShape.height
                radiusX: root._r
                radiusY: root._clampedRH3
            }
            PathLine {
                x: topRightShape.width
                y: 0
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Component {
        id: attachedRight
        BubbleShape {
            id: rightShape
            PathMove {
                x: rightShape.width
                y: rightShape.height
            }
            PathArc {
                x: Math.max(rightShape.width - root._r, root._halfW)
                y: rightShape.height - root._r
                radiusX: root._clampedRW
                radiusY: root._r
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root._clampedRW
                y: rightShape.height - root._r
            }
            PathArc {
                x: 0
                y: rightShape.height - root._r2
                radiusX: root._clampedRW
                radiusY: root._r
            }
            PathLine {
                x: 0
                y: root._r2
            }
            PathArc {
                x: root._clampedRW
                y: root._r
                radiusX: root._clampedRW
                radiusY: root._r
            }
            PathLine {
                x: Math.max(rightShape.width - root._r, root._halfW)
                y: root._r
            }
            PathArc {
                x: rightShape.width
                y: 0
                radiusX: root._clampedRW
                radiusY: root._r
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: rightShape.width
                y: rightShape.height
            }
        }
    }

    Component {
        id: attachedBottomRight
        BubbleShape {
            id: bottomRightShape
            PathMove {
                x: 0
                y: bottomRightShape.height
            }
            PathArc {
                x: root._r
                y: Math.max(bottomRightShape.height - root._r, 2 * root._thirdH)
                radiusX: root._r
                radiusY: root._clampedRH3
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root._r
                y: root._r2
            }
            PathArc {
                x: root._r2
                y: root._r
                radiusX: root._r
                radiusY: root._clampedRH3
            }
            PathLine {
                x: bottomRightShape.width - root._r
                y: root._r
            }
            PathArc {
                x: bottomRightShape.width
                y: 0
                radiusX: root._r
                radiusY: root._clampedRH3
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: bottomRightShape.width
                y: bottomRightShape.height
            }
            PathLine {
                x: 0
                y: bottomRightShape.height
            }
        }
    }

    Component {
        id: attachedBottom
        BubbleShape {
            id: bottomShape
            PathMove {
                x: 0
                y: bottomShape.height
            }
            PathArc {
                x: root._r
                y: Math.max(bottomShape.height - root._r, root._halfH)
                radiusX: root._r
                radiusY: root._clampedRH
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root._r
                y: root._clampedRH
            }
            PathArc {
                x: root._r2
                y: 0
                radiusX: root._r
                radiusY: root._clampedRH
            }
            PathLine {
                x: bottomShape.width - root._r2
                y: 0
            }
            PathArc {
                x: bottomShape.width - root._r
                y: root._clampedRH
                radiusX: root._r
                radiusY: root._clampedRH
            }
            PathLine {
                x: bottomShape.width - root._r
                y: Math.max(bottomShape.height - root._r, root._halfH)
            }
            PathArc {
                x: bottomShape.width
                y: bottomShape.height
                radiusX: root._r
                radiusY: root._clampedRH
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: 0
                y: bottomShape.height
            }
        }
    }

    Component {
        id: attachedBottomLeft
        BubbleShape {
            id: bottomLeftShape
            PathMove {
                x: bottomLeftShape.width
                y: bottomLeftShape.height
            }
            PathArc {
                x: bottomLeftShape.width - root._r
                y: Math.max(bottomLeftShape.height - root._r, 2 * root._thirdH)
                radiusX: root._r
                radiusY: root._clampedRH3
            }
            PathLine {
                x: bottomLeftShape.width - root._r
                y: root._r2
            }
            PathArc {
                x: bottomLeftShape.width - root._r2
                y: root._r
                radiusX: root._r
                radiusY: root._clampedRH3
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: root._r
                y: root._r
            }
            PathArc {
                x: 0
                y: 0
                radiusX: root._r
                radiusY: root._clampedRH3
            }
            PathLine {
                x: 0
                y: bottomLeftShape.height
            }
            PathLine {
                x: bottomLeftShape.width
                y: bottomLeftShape.height
            }
        }
    }

    Component {
        id: attachedLeft
        BubbleShape {
            id: leftShape
            PathMove {
                x: 0
                y: 0
            }
            PathArc {
                x: root._clampedRW
                y: root._r
                radiusX: root._clampedRW
                radiusY: root._r
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: Math.max(leftShape.width - root._r, root._halfW)
                y: root._r
            }
            PathArc {
                x: leftShape.width
                y: root._r2
                radiusX: root._clampedRW
                radiusY: root._r
            }
            PathLine {
                x: leftShape.width
                y: leftShape.height - root._r2
            }
            PathArc {
                x: Math.max(leftShape.width - root._r, root._halfW)
                y: leftShape.height - root._r
                radiusX: root._clampedRW
                radiusY: root._r
            }
            PathLine {
                x: root._clampedRW
                y: leftShape.height - root._r
            }
            PathArc {
                x: 0
                y: leftShape.height
                radiusX: root._clampedRW
                radiusY: root._r
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Component {
        id: attachedTopLeft
        BubbleShape {
            id: topLeftShape
            PathMove {
                x: topLeftShape.width
                y: 0
            }
            PathArc {
                x: topLeftShape.width - root._r
                y: root._clampedRH3
                radiusX: root._r
                radiusY: root._clampedRH3
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: topLeftShape.width - root._r
                y: Math.max(topLeftShape.height - root._r2, root._thirdH)
            }
            PathArc {
                x: topLeftShape.width - root._r2
                y: Math.max(topLeftShape.height - root._r, 2 * root._thirdH)
                radiusX: root._r
                radiusY: root._clampedRH3
            }
            PathLine {
                x: root._r
                y: Math.max(topLeftShape.height - root._r, 2 * root._thirdH)
            }
            PathArc {
                x: 0
                y: topLeftShape.height
                radiusX: root._r
                radiusY: root._clampedRH3
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: 0
                y: 0
            }
            PathLine {
                x: topLeftShape.width
                y: 0
            }
        }
    }
}