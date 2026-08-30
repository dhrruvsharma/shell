import QtQuick
import qs.colors

// Base text element for the shell. Only the colour is defaulted — font size and
// family stay whatever Text gives you, so swapping a plain `Text` for a
// `StyledText` never changes how it renders.
Text {
    color: Colors.on_surface
}
