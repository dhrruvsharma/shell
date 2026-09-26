pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Grabs every screen before a lock (or a preview) covers it, so its first
// frame can be identical to the desktop. Once the session is locked the
// compositor stops drawing the desktop, so this has to come first.
//
// Per screen: a ScreencopyView in an invisible 1x1 overlay, larger than its
// window on purpose (grabToImage renders the whole item offscreen, so nothing
// of it ever shows), then grabToImage. `finished` fires once every screen has
// a shot or `timeoutMs` has passed, whichever comes first.
Scope {
    id: cap

    property int timeoutMs: 400
    readonly property bool done: _done
    // screen name -> ItemGrabResult. Holding the result keeps its url valid.
    property var shots: ({})
    property bool _done: false

    signal finished

    function urlFor(screen) {
        const result = screen ? shots[screen.name] : undefined;
        return result ? result.url : "";
    }

    function finish() {
        if (_done)
            return;
        _done = true;
        finished();
    }

    function _keep(name, result) {
        if (_done)
            return;
        const next = Object.assign({}, shots);
        next[name] = result;
        shots = next;
        if (Object.keys(next).length >= Quickshell.screens.length)
            finish();
    }

    Timer {
        interval: cap.timeoutMs
        running: true
        onTriggered: cap.finish()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: grabber

            required property ShellScreen modelData

            screen: modelData
            visible: !cap.done
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:lock-capture"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.left: true
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            mask: Region {}

            ScreencopyView {
                id: view
                width: grabber.modelData.width
                height: grabber.modelData.height
                captureSource: grabber.modelData
                onHasContentChanged: {
                    if (hasContent)
                        Qt.callLater(() => view.grabToImage(result => cap._keep(grabber.modelData.name, result)));
                }
            }
        }
    }
}
