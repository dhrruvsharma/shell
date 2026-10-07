pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// The keyboard, showing one layer at a time: the keys bound with those
// modifiers held light up in their action's colour, and the modifier keys
// making up the layer are lit. Media keys and mouse buttons sit in a slim
// row underneath.
Item {
    id: board

    // the modifiers of the layer shown
    property var mods: []
    // key names (lower case)
    property string selectedKey: ""
    property string targetKey: ""
    property bool picking: false
    // a Set of matching bind ids while searching, else null
    property var matches: null
    property var appIcon: null

    signal keyClicked(var spec, var binds)
    signal keyDoubleClicked(var spec, var binds)
    // spec is null when the pointer leaves the keys
    signal keyHovered(var spec, var binds)

    readonly property real u: Math.min(52, width / KeyData.boardWidth)

    implicitHeight: u * KeyData.boardHeight

    component Cap: KeyCap {
        required property var modelData
        spec: modelData
        u: board.u
        binds: spec.mod ? [] : Services.Keybinds.bindsAt(board.mods, spec.name)
        modActive: board.mods.includes(spec.mod ?? "")
        selected: !board.picking && board.selectedKey !== "" && board.selectedKey === Services.Keybinds.norm(spec.name)
        target: board.picking && board.targetKey !== "" && board.targetKey === Services.Keybinds.norm(spec.name)
        picking: board.picking
        dimmed: board.matches !== null && !spec.mod && !binds.some(b => board.matches.has(b.id))
        appIcon: board.appIcon
        onClicked: board.keyClicked(spec, binds)
        onDoubleClicked: board.keyDoubleClicked(spec, binds)
        onHoverChanged: on => board.keyHovered(on ? spec : null, on ? binds : [])
    }

    Item {
        width: board.u * KeyData.boardWidth
        height: board.u * KeyData.boardHeight
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: KeyData.keys
            delegate: Cap {}
        }

        Repeater {
            model: KeyData.extras
            delegate: Cap {}
        }
    }
}
