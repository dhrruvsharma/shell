pragma Singleton
import QtQuick
import Quickshell

// Shared animation durations (ms) for the workspace disc port.
Singleton {
    id: root
    readonly property int fast: 150
    readonly property int slow: 350
}
