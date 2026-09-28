// SPDX-License-Identifier: GPL-3.0-or-later
//
// Derived from zesis-shell's widgets/workspaceindicator/disc/WorkspaceDiscService.qml.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis
// Modifications copyright (C) 2026 dhrruvsharma.
//
// Licensed under the GNU General Public License, version 3 or (at your
// option) any later version. See LICENSE in the repository root.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings for the workspace disc, stored in its own dedicated JSON file
// (not the shared settings.json) so the feature owns its data. Edit
// ~/.config/quickshell/config/workspacedisc.json and it live-reloads.
Singleton {
    id: root

    readonly property string _configPath: Quickshell.env("HOME") + "/.config/quickshell/config/workspacedisc.json"

    // Geometry / behaviour
    readonly property int workSpaceAmount:    settingsData.workSpaceAmount     // fixed chamber count when not expressive
    readonly property int minWorkSpaceAmount: settingsData.minWorkSpaceAmount  // floor when expressive
    readonly property int discRadius:         settingsData.discRadius
    readonly property int toothWidth:         settingsData.toothWidth          // gear tooth width % (0..100)
    readonly property int valleyDepth:        settingsData.valleyDepth         // gear valley depth % (0..100)
    readonly property int chamberRadius:      settingsData.chamberRadius       // orbit radius of chambers
    readonly property int chamberSize:        settingsData.chamberSize
    readonly property int peekOffset:         settingsData.peekOffset          // px the disc peeks out when collapsed
    readonly property bool expressive:        settingsData.expressive          // size the ring to live workspaces
    readonly property string skin:            settingsData.skin                // "default" | "waterwheel" | "gris"
    readonly property string corner:          settingsData.corner              // topLeft | topRight | bottomLeft | bottomRight

    FileView {
        path: root._configPath
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: settingsData
            property int workSpaceAmount: 6
            property int minWorkSpaceAmount: 1
            property int discRadius: 55
            property int toothWidth: 40
            property int valleyDepth: 28
            property int chamberRadius: 30
            property int chamberSize: 26
            property int peekOffset: 16
            property bool expressive: true
            property string skin: "default"
            property string corner: "bottomLeft"
        }
    }
}
