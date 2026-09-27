pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.lock
import qs.services as Services

// Lock screen, run as its own instance:
//   quickshell -p ~/.config/quickshell/Lock.qml
//
// 1. Grabs every screen first (ScreenCapture), so each lock surface can start
//    on a frame identical to the desktop.
// 2. Picks the theme (the desktop theme's matching one if it asks for it,
//    else services/LockScreen.qml: the active one, or a random one from the
//    active set in shuffle mode) and engages the session lock. Each
//    monitor gets that theme through ThemeHost; LockContext holds the shared
//    state and talks to PAM.
// 3. When PAM accepts the password and the reward/outro has played,
//    LockContext emits `released`: drop the lock and quit.
//
// Locking never waits more than ~450 ms: without a capture a theme fades in
// from black, without loaded settings the default theme is used.
ShellRoot {
    id: root

    property bool engaged: false
    property bool releasing: false
    property string themeId: ""
    readonly property bool settingsReady: Services.LockScreen.ready && Services.DesktopTheme.ready

    function maybeEngage() {
        if (capture.done && settingsReady)
            engage();
    }

    function engage() {
        if (engaged)
            return;
        engaged = true;
        // A desktop theme can ask for its matching lock screen.
        themeId = Services.DesktopTheme.lockTheme || Services.LockScreen.pick();
        Services.LockScreen.remember(themeId);
        lockCtx.configure(Services.LockScreen.theme(themeId));
        lockCtx.begin();
        sessionLock.locked = true;
    }

    function release() {
        if (releasing)
            return;
        releasing = true;
        sessionLock.locked = false;
        quitTimer.start();
    }

    onSettingsReadyChanged: maybeEngage()

    ScreenCapture {
        id: capture
        onFinished: root.maybeEngage()
    }

    // Hard cap: lock now, whatever is still loading.
    Timer {
        interval: 450
        running: true
        onTriggered: root.engage()
    }

    Timer {
        id: quitTimer
        interval: 150
        onTriggered: Qt.quit()
    }

    LockContext {
        id: lockCtx
        onReleased: root.release()
    }

    WlSessionLock {
        id: sessionLock

        // `secure` follows the compositor: true once every screen is covered,
        // false if it refuses the lock (another locker holds it) or ends it.
        // Then there's nothing left to guard. (`locked` can't be watched for
        // this: Quickshell doesn't notify it when the compositor unlocks.)
        onSecureChanged: {
            if (!secure && root.engaged && !root.releasing) {
                console.warn("lock: session lock refused or ended by the compositor, exiting");
                Qt.quit();
            }
        }

        WlSessionLockSurface {
            id: lockSurface
            color: "black"

            ThemeHost {
                anchors.fill: parent
                ctx: lockCtx
                themeId: root.themeId
                shot: capture.urlFor(lockSurface.screen)
                shown: lockSurface.visible
            }
        }
    }
}
