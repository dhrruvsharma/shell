pragma ComponentBehavior: Bound
import QtQuick

// The pages between, on a jump of several: a few blank leaves fanning over
// just behind the one that turns, landing with it.
Item {
    id: riffle

    property real pageW: 740
    property real pageH: 900
    property real dir: 1
    property real progress: 0
    property int leaves: 0

    width: riffle.pageW * 2
    height: riffle.pageH

    // The blank stock they're cut from: a right-hand page and a left-hand
    // one, with a few lines of grey type on each. Only ever seen in the
    // leaves: they're kept under a clip of no size.
    Item {
        width: 0
        height: 0
        clip: true

        Repeater {
            id: blanks
            model: 2

            Item {
                required property int index
                width: riffle.pageW
                height: riffle.pageH

                Paper {
                    anchors.fill: parent
                    spineSide: index === 0 ? 1 : 0
                    seed: 31 + index
                }

                Column {
                    x: 70
                    y: 120
                    spacing: 13

                    Repeater {
                        model: 26

                        Rectangle {
                            required property int index
                            width: (riffle.pageW - 140) * (index % 7 === 6 ? 0.45 : 0.82 + 0.18 * ((index * 37) % 10) / 10)
                            height: 4
                            radius: 2
                            color: BookStyle.inkFaint
                            opacity: 0.35
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: riffle.leaves

        PageTurn {
            required property int index
            readonly property real lag: 0.07 * (index + 1)

            pageW: riffle.pageW
            pageH: riffle.pageH
            dir: riffle.dir
            active: riffle.leaves > 0 && riffle.progress > lag && riffle.progress < 0.995
            progress: Math.max(0, Math.min(1, (riffle.progress - lag) / (1 - lag)))
            frontItem: blanks.itemAt(riffle.dir > 0 ? 0 : 1)
            backItem: blanks.itemAt(riffle.dir > 0 ? 1 : 0)
        }
    }
}
