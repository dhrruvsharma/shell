pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// The screen-share picker's link to scripts/share-picker, which the portal
// runs when an app asks to share the screen (custom_picker_binary in
// hypr/xdph.conf). The script listens on a socket and calls `open` with its
// path; the request comes in as a line of JSON, `shown` says the picker is up
// and `finish` sends the answer. The link is also how each side knows the
// other is there: a script that gives up closes it and the picker goes, and
// a reload here drops it and the script hands over to the stock picker.
Singleton {
    id: root

    // An app is waiting on the picker.
    property bool asking: false
    // What it can share (modules/sharepicker). Kept after `asking` goes: the
    // picker's window still reads it on its way out.
    //   remember  the portal's default for `remember`
    //   preview   no portal is waiting (share-picker --preview)
    //   focused   the screen to show the picker on
    //   rounding  Hyprland's corners, as windows have them on screen
    //   outputs   [{ name, description, x, y, w, h }], layout coordinates
    //   windows   [{ id, address, class, title, workspace, showing, output,
    //                x, y, w, h }], bottom to top
    //   shelf     [{ workspace, name, output, windows, showing, capture }],
    //             workspaces; capture is the portal's id for one, 0 if it
    //             can't be shared whole
    property var session: null
    // Whether the app may skip the picker next time.
    property bool remember: false

    property Socket _link: null

    function open(path: string): string {
        if (!path)
            return "no path";
        // The portal only asks again once it has been answered: anything
        // still here is a request nobody's waiting on.
        const old = _link;
        _link = null;
        asking = false;
        if (old)
            old.connected = false;

        const link = linkType.createObject(root, {
            path: path,
            connected: true
        }) as Socket;
        if (!link?.connected) {
            link?.destroy();
            return "couldn't connect";
        }
        _link = link;
        return "ok";
    }

    // The picker is on screen.
    function shown() {
        _say("up");
    }

    // What was chosen, as selection() words it ("" for nothing), once the
    // picker has gone. Not before: a share of the screen would catch it.
    function finish(answer) {
        _say(answer || "cancel");
        _link = null;
        asking = false;
    }

    // A choice, in the portal's words. Each kind has its own key:
    //   { kind: "output", key: name }
    //   { kind: "window", key: id }
    //   { kind: "workspace", key: capture }
    //   { kind: "region", key: "", output, x, y, w, h }
    function selection(target) {
        const head = "[SELECTION]" + (remember ? "r" : "") + "/";
        switch (target?.kind) {
        case "output":
            return head + "screen:" + target.key;
        case "window":
            return head + "window:" + target.key;
        case "workspace":
            return head + "workspace-id:" + target.key;
        case "region":
            return head + "region:" + target.output + "@" + target.x + "," + target.y + "," + target.w + "," + target.h;
        default:
            return "";
        }
    }

    function _say(line) {
        if (!_link)
            return;
        _link.write(line + "\n");
        _link.flush();
    }

    function _received(link, line) {
        if (link !== _link || asking)
            return;
        try {
            const request = JSON.parse(line);
            remember = request.remember === true;
            session = request;
            asking = true;
        } catch (e) {
            console.warn("ScreenShare: can't read the request:", e);
            link.connected = false;
        }
    }

    function _lost(link) {
        if (link === _link) {
            _link = null;
            asking = false;
        }
        link.destroy();
    }

    Component {
        id: linkType

        Socket {
            id: link

            parser: SplitParser {
                onRead: line => root._received(link, line)
            }
            onConnectionStateChanged: {
                if (!connected)
                    root._lost(link);
            }
        }
    }
}
