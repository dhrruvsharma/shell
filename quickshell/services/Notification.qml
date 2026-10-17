pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
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

    // A click: the app's default action (invoking closes it, unless it's
    // resident), else it's just put away.
    function activate(n): void {
        const action = defaultAction(n);
        if (action)
            action.invoke();
        else
            dismiss(n);
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

        // A toast goes after the app's timeout (5 s when it gives none); a
        // critical one stays until it's dealt with.
        readonly property Timer timer: Timer {
            running: notif.popup && !notif.critical
            interval: (notif.notification?.expireTimeout ?? 0) > 0 ? notif.notification.expireTimeout : 5000
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
        }
    }
}
