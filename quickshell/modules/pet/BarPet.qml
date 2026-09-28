pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// The pet's life in the top bar (services/Pet.qml has its memory). It roams
// the free stretches between the bar's islands (it passes behind them when
// it crosses), sits, grooms, looks round and naps (always while you're
// away, and at night if you like), and acts out what the service asks:
// pats, meals, play, a reminder. Click it for its hub; right-click or
// scroll over it to pat it; drag it to pick it up and drop it elsewhere.
//
// It only animates while something moves, stepping at 30 fps; at rest the
// bar doesn't repaint.
Item {
    id: pet

    // The bar's free stretches, [[from, to], ...] in this item's x.
    property var gaps: [[0, width]]
    readonly property var coat: Services.Pet.coat
    readonly property real figW: 46
    readonly property real figH: 40
    readonly property real floorY: height - 2

    property real px: -1
    property int facing: 1
    property string pose: "stand"
    property real phase: 0
    property real blink: 0
    property real lift: 0
    property real squash: 1
    property real swing: 0
    property real hearts: 0
    property bool alert: false

    property real targetX: 0
    property real speed: 38
    property bool walking: false
    property bool dragging: false
    property bool falling: false
    property real vy: 0
    // Short animations in flight: { kind, t, dur }.
    property var tweens: []
    // A pose held until then (ms), before the brain may change it.
    property double holdUntil: 0

    readonly property bool busy: walking || dragging || falling || tweens.length > 0
    readonly property bool awake: pose !== "sleep"
    // Set once the bar has laid out, so it doesn't start behind an island.
    property bool placed: false

    visible: Services.Pet.shown && placed

    // ── Where it may go ──────────────────────────────────────────────────────
    function territory() {
        const g = pet.gaps.filter(s => s[1] - s[0] > pet.figW + 8);
        if (g.length === 0)
            return [[pet.figW / 2, pet.width - pet.figW / 2]];
        const roam = Services.Pet.roam;
        if (roam === "left")
            return [g[0]];
        if (roam === "right")
            return [g[g.length - 1]];
        return g;
    }

    function inGap(x) {
        return pet.territory().some(s => x >= s[0] + pet.figW / 2 && x <= s[1] - pet.figW / 2);
    }

    // The nearest spot in a gap to x.
    function nearestSpot(x) {
        let best = x, dist = 1e9;
        for (const s of pet.territory()) {
            const a = s[0] + pet.figW / 2 + 4, b = s[1] - pet.figW / 2 - 4;
            if (b < a)
                continue;
            const c = Math.max(a, Math.min(b, x));
            if (Math.abs(c - x) < dist) {
                dist = Math.abs(c - x);
                best = c;
            }
        }
        return best;
    }

    function randomSpot() {
        const t = pet.territory();
        // Mostly somewhere in the stretch it's already in.
        let span = t.find(s => pet.px >= s[0] && pet.px <= s[1]);
        if (!span || Math.random() < 0.3)
            span = t[Math.floor(Math.random() * t.length)];
        const a = span[0] + pet.figW / 2 + 6, b = span[1] - pet.figW / 2 - 6;
        return b > a ? a + Math.random() * (b - a) : (span[0] + span[1]) / 2;
    }

    // An island grew or moved over it: step out.
    onGapsChanged: {
        if (pet.placed && !pet.dragging && !pet.falling && !pet.walking && !pet.inGap(pet.px))
            pet.walkTo(pet.nearestSpot(pet.px));
    }

    // The islands fill in over the bar's first moments; after that it
    // appears somewhere in the biggest stretch.
    Timer {
        interval: 1500
        running: !pet.placed
        onTriggered: {
            const t = pet.territory().slice().sort((x, y) => (y[1] - y[0]) - (x[1] - x[0]));
            const s = t[0];
            pet.px = (s[0] + s[1]) / 2 + (Math.random() - 0.5) * Math.min(120, (s[1] - s[0]) / 3);
            pet.placed = true;
        }
    }

    onPxChanged: Services.Pet.barX = pet.mapToItem(null, pet.px, 0).x

    // ── Moving ───────────────────────────────────────────────────────────────
    function walkTo(x) {
        if (!pet.awake || Services.Pet.roam === "still" && !pet.dragging && pet.inGap(pet.px))
            return;
        pet.targetX = x;
        if (Math.abs(x - pet.px) < 2)
            return;
        pet.facing = x > pet.px ? 1 : -1;
        pet.pose = "walk";
        pet.walking = true;
    }

    function stop(nextPose) {
        pet.walking = false;
        pet.pose = nextPose ?? "stand";
    }

    function tween(kind, dur) {
        const list = pet.tweens.filter(t => t.kind !== kind);
        list.push({ kind: kind, t: 0, dur: dur });
        pet.tweens = list;
    }

    function hop(times) {
        pet.tween("hop", 420 * (times ?? 1));
    }

    function hold(p, ms) {
        if (pet.walking)
            pet.stop(p);
        pet.pose = p;
        pet.holdUntil = Date.now() + ms;
        brain.interval = ms + 150;
        brain.restart();
    }

    function sleep() {
        pet.walking = false;
        pet.pose = "sleep";
        pet.alert = false;
        Services.Pet.asleep = true;
        brain.interval = 30000;
        brain.restart();
    }

    function wake() {
        if (pet.awake)
            return;
        Services.Pet.asleep = false;
        pet.hold("sit", 4000);
        pet.tween("stretch", 700);
    }

    // One step of every animation in flight.
    function step(dt) {
        if (pet.walking) {
            const d = pet.targetX - pet.px;
            const move = Math.min(Math.abs(d), pet.speed * dt);
            pet.px += Math.sign(d) * move;
            pet.phase += dt * (Services.Pet.species === "bunny" ? 7 : 9);
            if (Math.abs(pet.targetX - pet.px) < 0.5) {
                const r = Math.random();
                pet.stop(r < 0.45 ? "sit" : r < 0.7 ? "look" : "stand");
            }
        }
        const gait = pet.walking && Services.Pet.species === "bunny" ? Math.abs(Math.sin(pet.phase * 0.5)) * 4 : 0;
        if (pet.falling) {
            pet.vy += 900 * dt;
            pet.lift = Math.max(0, pet.lift - pet.vy * dt);
            pet.swing *= 0.8;
            if (pet.lift <= 0) {
                pet.falling = false;
                pet.swing = 0;
                pet.tween("land", 260);
                pet.hold("look", 1500);
                if (!pet.inGap(pet.px))
                    Qt.callLater(() => pet.walkTo(pet.nearestSpot(pet.px)));
            }
        }
        if (pet.dragging)
            pet.swing *= 0.86;
        let changed = gait > 0 || (pet.lift > 0 && !pet.dragging && !pet.falling);
        const next = [];
        let lift = gait, squash = 1, hearts = 0, blink = 0;
        for (const t of pet.tweens) {
            const tt = Object.assign({}, t);
            tt.t += dt * 1000;
            const k = Math.min(1, tt.t / tt.dur);
            if (tt.kind === "hop") {
                const n = Math.max(1, Math.round(tt.dur / 420));
                const local = (k * n) % 1;
                lift = Math.max(lift, Math.sin(local * Math.PI) * 9);
                squash = local < 0.12 || local > 0.9 ? 0.86 : 1.04;
            } else if (tt.kind === "land") {
                squash = 1 - Math.sin(k * Math.PI) * 0.16;
            } else if (tt.kind === "stretch") {
                squash = 1 + Math.sin(k * Math.PI) * 0.1;
            } else if (tt.kind === "hearts") {
                hearts = k < 1 ? Math.max(0.001, k) : 0;
            } else if (tt.kind === "blink") {
                blink = Math.sin(k * Math.PI);
            } else if (tt.kind === "sway") {
                pet.phase += dt * 3;
            }
            if (k < 1)
                next.push(tt);
            changed = true;
        }
        if (changed) {
            if (pet.tweens.length > 0)
                pet.tweens = next;
            if (!pet.dragging && !pet.falling)
                pet.lift = lift;
            pet.squash = squash;
            pet.hearts = hearts;
            pet.blink = blink;
        }
    }

    Timer {
        id: tick

        property double last: 0

        interval: 33
        repeat: true
        running: pet.busy && pet.visible
        onRunningChanged: last = Date.now()
        onTriggered: {
            const t = Date.now();
            pet.step(Math.min(0.1, (t - last) / 1000));
            last = t;
        }
    }

    // ── Deciding what to do next ─────────────────────────────────────────────
    function think() {
        brain.interval = pet.awake ? 8000 + Math.random() * 16000 : 30000;
        if (pet.dragging || pet.falling)
            return;
        const wait = pet.holdUntil - Date.now();
        if (wait > 0) {
            brain.interval = wait + 150;
            return;
        }
        if (Services.Pet.hubOpen) {
            if (pet.walking)
                pet.stop("look");
            return;
        }
        // Behind an island (a pat or a nap stopped it on the way): out first.
        if (!pet.inGap(pet.px)) {
            if (!pet.awake)
                pet.wake();
            else
                pet.walkTo(pet.nearestSpot(pet.px));
            return;
        }
        const svc = Services.Pet;
        // Out for the count while you're away, or until rested once tired;
        // at night (if it keeps night hours) it dozes on and off.
        const tired = idle.isIdle || svc.energy < (pet.awake ? 0.2 : 0.6);
        const drowsy = svc.sleepAtNight && svc.night;
        if (!pet.awake) {
            if (!tired && (!drowsy || Math.random() < 0.15)) {
                pet.wake();
                svc.chat(2, svc.pick("wake"));
            }
            return;
        }
        if ((tired && Math.random() < 0.7) || (drowsy && Math.random() < 0.35)) {
            pet.sleep();
            return;
        }
        if (pet.pose === "happy" || pet.pose === "eat" || pet.pose === "dangle")
            pet.pose = "sit";
        const r = Math.random();
        const still = svc.roam === "still";
        if (!still && r < (svc.mood === "bored" ? 0.6 : 0.42)) {
            pet.walkTo(pet.randomSpot());
        } else if (r < 0.62) {
            pet.pose = "sit";
        } else if (r < 0.72) {
            pet.hold("groom", 2600);
            pet.tween("sway", 2400);
        } else if (r < 0.86) {
            pet.pose = "look";
            pet.facing = Math.random() < 0.5 ? 1 : -1;
        } else {
            pet.pose = "stand";
            pet.tween("sway", 1500);
        }
    }

    Timer {
        id: brain
        interval: 4000
        repeat: true
        running: pet.visible
        onTriggered: pet.think()
    }

    Timer {
        interval: 3000 + Math.random() * 5000
        repeat: true
        running: pet.visible && pet.awake
        onTriggered: {
            interval = 3000 + Math.random() * 5000;
            if (!pet.walking)
                pet.tween("blink", 160);
        }
    }

    // Asleep while you're away.
    IdleMonitor {
        id: idle
        timeout: 240
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                if (pet.awake && !Services.Pet.hubOpen)
                    pet.sleep();
            } else if (!pet.awake && !(Services.Pet.sleepAtNight && Services.Pet.night)) {
                pet.wake();
            }
        }
    }

    // ── What the service asks for ────────────────────────────────────────────
    Connections {
        target: Services.Pet

        function onAct(what) {
            switch (what) {
            case "pat":
                pet.hold("happy", 1600);
                pet.tween("hearts", 1300);
                pet.tween("land", 240);
                break;
            case "feed":
                pet.hold("eat", 2600);
                pet.tween("hearts", 1600);
                break;
            case "play":
                pet.hold("happy", 1800);
                pet.hop(2);
                pet.facing = -pet.facing;
                break;
            case "nap":
                pet.sleep();
                pet.holdUntil = Date.now() + 5 * 60000;
                break;
            case "wake":
                pet.wake();
                break;
            case "notice":
                if (pet.awake) {
                    pet.hold("look", 2000);
                    pet.alert = true;
                    alertOff.restart();
                }
                break;
            case "run":
                pet.hop(1);
                break;
            case "alert":
                pet.wake();
                pet.hold("look", 3000);
                pet.alert = true;
                alertOff.restart();
                pet.hop(2);
                break;
            case "happy":
            case "levelup":
                pet.hold("happy", 2000);
                pet.hop(1);
                pet.tween("hearts", 1400);
                break;
            }
        }

        function onHubOpenChanged() {
            if (Services.Pet.hubOpen && pet.awake)
                pet.hold(pet.walking ? "look" : pet.pose === "sit" ? "sit" : "look", 1500);
        }

        function onBubbleSerialChanged() {
            if (pet.walking)
                pet.stop("sit");
        }
    }

    Timer {
        id: alertOff
        interval: 1600
        onTriggered: pet.alert = false
    }

    // ── The pet ──────────────────────────────────────────────────────────────
    PetFigure {
        id: figure
        x: pet.px - width / 2
        y: pet.floorY - height
        width: pet.figW
        height: pet.figH
        z: pet.dragging ? 10 : 0
        pose: pet.pose
        facing: pet.facing
        phase: pet.phase
        blink: pet.blink
        lift: pet.lift
        squash: pet.squash
        swing: pet.swing
        hearts: pet.hearts
        alert: pet.alert
        species: Services.Pet.species
        coat: pet.coat
        costume: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
        accent: Services.DesktopTheme.accent
        accent2: Services.DesktopTheme.accent2
    }

    MouseArea {
        id: hand

        property real pressX: 0
        property real lastX: 0
        property bool moved: false
        property double lastWheel: 0

        x: figure.x + 4
        y: 0
        width: figure.width - 8
        height: pet.height
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: pet.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onEntered: {
            if (pet.awake && !pet.walking && !pet.dragging && Date.now() > pet.holdUntil)
                pet.hold("look", 1200);
        }
        onPressed: mouse => {
            pressX = mapToItem(pet, mouse.x, mouse.y).x;
            lastX = pressX;
            moved = false;
        }
        onPositionChanged: mouse => {
            if (!pressed || mouse.buttons !== Qt.LeftButton)
                return;
            const x = mapToItem(pet, mouse.x, mouse.y).x;
            if (!moved && Math.abs(x - pressX) > 6) {
                moved = true;
                pet.dragging = true;
                pet.walking = false;
                if (!pet.awake)
                    Services.Pet.asleep = false;
                pet.pose = "dangle";
                pet.lift = 5;
                Services.Pet.touch();
            }
            if (pet.dragging) {
                pet.swing = Math.max(-0.5, Math.min(0.5, pet.swing + (x - lastX) * 0.02));
                pet.px = Math.max(pet.figW / 2, Math.min(pet.width - pet.figW / 2, x));
                lastX = x;
            }
        }
        onReleased: mouse => {
            if (pet.dragging) {
                pet.dragging = false;
                pet.falling = true;
                pet.vy = 0;
                return;
            }
            if (moved)
                return;
            if (mouse.button === Qt.RightButton)
                Services.Pet.pat();
            else
                Services.Pet.toggleHub();
        }
        onWheel: wheel => {
            if (Date.now() - lastWheel > 700) {
                lastWheel = Date.now();
                Services.Pet.pat();
            }
        }
    }
}
