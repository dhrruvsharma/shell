pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick

// The notification server, and what the shell shows of it: `history`, every
// notification still open (oldest first), for the control centre, and
// `popups` for the toasts. Do not disturb holds the toasts back, all but
// critical ones; the notifications still land in the history. It's kept in
// notifications.json, so it outlives a restart.
Singleton {
    id: root

    property list<Notif> data: []
    readonly property list<Notif> popups: data.filter(n => n.popup && (!adapter.dnd || n.critical))
    readonly property list<Notif> history: data

    readonly property bool dnd: adapter.dnd
    // How long a toast stays when its app doesn't say (the customizer sets it).
    readonly property int toastSeconds: Math.max(2, Math.min(60, adapter.toastSeconds))

    function setToastSeconds(s: int): void {
        adapter.toastSeconds = Math.round(Math.max(2, Math.min(60, s)));
    }

    function setDnd(on: bool): void {
        adapter.dnd = on;
    }

    function toggleDnd(): void {
        adapter.dnd = !adapter.dnd;
    }

    // Closes it, telling the app it was dismissed; it leaves the lists when
    // the server reports it closed.
    function dismiss(n): void {
        if (!n)
            return;
        n.popup = false;
        if (n.notification)
            n.notification.dismiss();
        else
            _drop(n);
    }

    function clearAll(): void {
        for (const n of data.slice())
            dismiss(n);
    }

    // The action a click on the notification runs, if the app gave one.
    function defaultAction(n): var {
        return n?.actions.find(a => a.identifier === "default") ?? null;
    }

    // A click: the toast goes, the app's default action runs (invoking
    // closes it, unless it's resident), and the app's window is brought
    // forward. Apps can't raise themselves on Wayland without an activation
    // token, which the notification spec's ActionInvoked doesn't carry, so
    // a Discord or Firefox would switch to the message but stay behind.
    // With no default action it's put away from the control centre
    // (`dismissIdle`); a toast just goes back to the history.
    function activate(n, dismissIdle = true): void {
        if (!n)
            return;
        // A screenshot's (scripts/screenshot) is the shell's own: it opens
        // in the editor.
        if (Screenshot.owns(n)) {
            Screenshot.act(n, "default");
            return;
        }
        const action = defaultAction(n);
        const app = [n.desktopEntry, n.appName];
        n.popup = false;
        if (action)
            action.invoke();
        else if (dismissIdle)
            dismiss(n);
        focusApp(app);
    }

    // One of the app's own buttons. The app usually closes it after.
    function invoke(n, action): void {
        if (!n || !action)
            return;
        if (Screenshot.owns(n)) {
            Screenshot.act(n, action.identifier);
            return;
        }
        const app = [n.desktopEntry, n.appName];
        n.popup = false;
        action.invoke();
        focusApp(app);
    }

    // Sends the text back to the app (a chat's inline reply). The app
    // closes or replaces the notification itself.
    function reply(n, text: string): void {
        if (!n?.notification || !n.canReply || text.trim().length === 0)
            return;
        // A screenshot's: the file's new name.
        if (Screenshot.owns(n)) {
            Screenshot.reply(n, text);
            return;
        }
        n.popup = false;
        n.notification.sendInlineReply(text);
    }

    // Brings forward the newest window of the app named in `names` (its
    // desktop entry, its name): matched against window classes, whole or
    // as the tail of a reverse-DNS id (org.telegram.desktop ↔ telegram).
    // Skipped when the action itself moved focus to something else (a
    // download notification opening the file manager, say).
    function focusApp(names): void {
        const wanted = names.map(s => (s ?? "").toLowerCase().replace(/\.desktop$/, "")).filter(s => s.length > 1);
        if (wanted.length === 0)
            return;
        focuser.wanted = wanted;
        focuser.before = String(ToplevelManager.activeToplevel?.appId ?? "").toLowerCase();
        focusDelay.restart();
    }

    function _matches(cls: string, wanted): bool {
        cls = (cls ?? "").toLowerCase();
        if (!cls)
            return false;
        const tail = cls.split(".").pop();
        return wanted.some(w => cls === w || tail === w || w.split(".").pop() === cls || (w.length >= 4 && cls.includes(w)));
    }

    // Gives the app a moment to raise its own window first.
    Timer {
        id: focusDelay
        interval: 220
        onTriggered: focuser.running = true
    }

    Process {
        id: focuser

        property var wanted: []
        property string before

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let clients;
                try {
                    clients = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const active = clients.find(c => c.focusHistoryID === 0);
                // Already there, or the action opened something else.
                if (active && (root._matches(active.class, focuser.wanted) || root._matches(active.initialClass, focuser.wanted)))
                    return;
                if (active && focuser.before && (active.class ?? "").toLowerCase() !== focuser.before)
                    return;
                const target = clients.filter(c => c.mapped !== false && (root._matches(c.class, focuser.wanted) || root._matches(c.initialClass, focuser.wanted))).sort((a, b) => a.focusHistoryID - b.focusHistoryID)[0];
                if (target)
                    Hyprland.dispatch("focuswindow address:" + target.address);
            }
        }
    }

    // The app's icon as an image URL ("" for none): its own icon, an icon
    // named in the image hint, or its desktop entry's. Names are looked up
    // in the icon theme first: a missing one would draw as a checkerboard.
    function iconOf(n): string {
        if (!n)
            return "";
        const icon = n.appIcon;
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        const named = icon || (n.image.startsWith("image://icon/") ? n.image.slice(13) : "") || n.desktopEntry;
        return named ? Quickshell.iconPath(named, true) : "";
    }

    // A picture that comes with it (a screenshot, album art, someone's
    // avatar), as opposed to an icon: "" for none.
    function pictureOf(n): string {
        const image = n?.image ?? "";
        if (!image || image.startsWith("image://icon/"))
            return "";
        return image.startsWith("/") ? "file://" + image : image;
    }

    function removeById(id) {
        const n = data.find(n => n.notification?.id === id);
        if (n)
            _drop(n);
    }

    // (indexOf is -1 for one already gone, and splice(-1, 1) would take the
    // last one instead)
    function _drop(n): void {
        const i = data.indexOf(n);
        if (i >= 0)
            data.splice(i, 1);
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notif => {
            notif.tracked = true;

            root.data.push(notifComp.createObject(root, {
                popup: true,
                notification: notif
            }));
        }
    }

    component Notif: QtObject {
        id: notif

        property bool popup
        readonly property date time: new Date()
        readonly property string timeStr: {
            // (a reload tears these down after the clock has gone: say
            // nothing then rather than fail)
            try {
                const diff = Time.date.getTime() - time.getTime();
                const m = Math.floor(diff / 60000);
                const h = Math.floor(m / 60);

                if (h < 1 && m < 1)
                    return "now";
                if (h < 1)
                    return `${m}m`;
                if (h < 24)
                    return `${h}h`;
                return `${Math.floor(h / 24)}d`;
            } catch (e) {
                return "";
            }
        }

        required property Notification notification
        readonly property string summary: notification?.summary ?? ""
        readonly property string body: notification?.body ?? ""
        readonly property string appIcon: notification?.appIcon ?? ""
        readonly property string appName: notification?.appName ?? ""
        readonly property string desktopEntry: notification?.desktopEntry ?? ""
        readonly property string image: notification?.image ?? ""
        readonly property int urgency: notification?.urgency ?? NotificationUrgency.Normal
        readonly property bool critical: urgency === NotificationUrgency.Critical
        readonly property list<NotificationAction> actions: notification?.actions ?? []
        readonly property bool canReply: notification?.hasInlineReply ?? false
        readonly property string replyPlaceholder: notification?.inlineReplyPlaceholder ?? ""

        // Held while the pointer's on its toast or a reply is being typed:
        // the countdown stops and starts over once it's let go.
        property bool held: false
        // A reply to it is being typed (its toast takes the keyboard).
        property bool replying: false

        // A toast goes after the app's timeout (toastSeconds when it gives
        // none); a critical one stays until it's dealt with.
        readonly property Timer timer: Timer {
            running: notif.popup && !notif.critical && !notif.held
            interval: (notif.notification?.expireTimeout ?? 0) > 0 ? notif.notification.expireTimeout : root.toastSeconds * 1000
            onTriggered: notif.popup = false
        }

        readonly property Connections conn: Connections {
            target: notif.notification.Retainable

            function onDropped(): void {
                root._drop(notif);
            }

            function onAboutToDestroy(): void {
                notif.destroy();
            }
        }

        readonly property Connections conn2: Connections {
            target: notif.notification

            function onClosed(reason) {
                root._drop(notif);
            }
        }
    }

    Component {
        id: notifComp

        Notif {}
    }

    // ── Do not disturb, kept across restarts ────────────────────────────────
    Timer {
        id: writeTimer
        interval: 200
        onTriggered: stateFile.writeAdapter()
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.config/quickshell/notifications.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()

        adapter: JsonAdapter {
            id: adapter
            property bool dnd: false
            property int toastSeconds: 5
        }
    }
}
