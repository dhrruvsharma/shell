pragma Singleton
import QtQuick
import Quickshell

// Global UI scale factor + a couple of derived font sizes, used by the
// workspace disc port. Kept trivial; bump `value` to scale the whole disc.
Singleton {
    id: root
    property real value: 1.0
    readonly property int fontTiny: Math.round(12 * value)
}
