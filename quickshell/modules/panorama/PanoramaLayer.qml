import QtQuick
import Quickshell

// The panorama's surface on every screen (see PanoramaSurface).
Scope {
    Variants {
        model: Quickshell.screens

        PanoramaSurface {}
    }
}
