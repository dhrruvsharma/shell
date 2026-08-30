import QtQuick
import qs.colors

// Hairline separator.
//
// NOTE: `height` (not implicitHeight) matches what every call site did before this
// component existed. Inside a Layout that means the layout still controls the final
// height, exactly as it did previously — see the note in the refactor summary.
Rectangle {
    height: 1
    color: Colors.outline_variant
}
