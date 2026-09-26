import QtQuick

// A Material Symbols icon, named by its ligature ("lock", "favorite", ...).
// `filled` switches the font's FILL axis, so one glyph serves as both the
// outlined and the solid form (e.g. full vs. lost hearts).
Text {
    property bool filled: false
    property int weight: 500

    font.family: LockTheme.icons
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": weight })
    color: LockTheme.ink
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
