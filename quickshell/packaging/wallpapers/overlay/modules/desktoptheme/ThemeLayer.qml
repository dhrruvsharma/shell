import QtQuick

// In the rice, the desktop theme draws its decorations over the wallpaper
// here. The standalone picker has no themes; the wallpaper layer never
// loads this, it only needs the type.
Item {
    property var wallpaper: null
    readonly property bool usesWallpaper: false
}
