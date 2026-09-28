pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.lock
import qs.services as Services

// "Extra! Extra!" theme: the front page of your own newspaper.
//
// Lock-in: the desktop shrinks into the page as its photograph, printed in
// halftone as it goes, and the front page sets up around it: the masthead,
// the dateline, the lead story (that you've stepped away), short items from
// the machine itself, the radio listings and the classifieds. The passcode
// fills today's crossword, a square a keystroke (never what was typed). A
// wrong one prints a correction (the faillock lives are the corrections the
// desk allows); a lockout halts the presses. Getting in spins an EXTRA
// edition onto the screen (circulation is XP, and promotions come in the
// newsroom), then the photograph grows back into the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: paper

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real margin: 56 * sc

    // Choreography.
    property real photoIn: 0
    property real pageIn: 0
    property real uiIn: 0
    property real stamp: 0
    property real extra: 0
    property real rewardIn: 0
    property real promote: 0
    property real shakeX: 0

    // Circulation (XP) on the byline: follows the stored XP, but runs up
    // from the old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    // Corrections printed so far (one per rejected passcode).
    property int corrections: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool halted: ctx.lockedOut && ctx.cells === 0
    readonly property string user: ctx.userName
    readonly property string userCap: user.charAt(0).toUpperCase() + user.slice(1)
    readonly property string lockedAtText: Press.time(new Date(ctx.lockedAt))

    // Where the photograph sits on the page.
    readonly property rect photoSlot: Qt.rect(margin, 430 * sc, 740 * sc, 740 * sc * height / Math.max(1, width))

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            photoIn = 1;
            pageIn = 1;
            uiIn = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            promoteFx.restart();
        _seenLevel = shownLevel;
    }

    onShownChanged: if (shown && !still) startIntro()

    property bool _introStarted: false

    function startIntro() {
        if (_introStarted)
            return;
        _introStarted = true;
        introFallback.stop();
        intro.start();
    }

    Timer {
        id: introFallback
        interval: 500
        onTriggered: paper.startIntro()
    }

    Connections {
        target: paper.ctx

        function onPhaseChanged() {
            if (paper.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            paper.corrections += 1;
            deniedFx.restart();
        }

        function onGranted() {
            if (paper.reward) {
                paper.rewarding = true;
                paper.shownXp = paper.reward.xpBefore;
                circulationFill.restart();
            }
            grantFx.restart();
        }
    }

    // Ends a sentence, unless the text already does ("10:09 p.m.").
    function stop(text) {
        return text.endsWith(".") ? text : text + ".";
    }

    // "2 hours 14 minutes"
    function away(ms) {
        const m = Math.max(0, Math.round(ms / 60000));
        if (m < 1)
            return "a few seconds";
        const h = Math.floor(m / 60);
        const parts = [];
        if (h > 0)
            parts.push(h + (h === 1 ? " hour" : " hours"));
        if (m % 60 > 0)
            parts.push(m % 60 + (m % 60 === 1 ? " minute" : " minutes"));
        return parts.join(" ");
    }

    // ── The page ─────────────────────────────────────────────────────
    component Body: Text {
        font.family: Press.body
        font.pixelSize: 16 * paper.sc
        color: Press.ink
        wrapMode: Text.WordWrap
        lineHeight: 1.08
    }

    component Head: Text {
        font.family: Press.body
        font.pixelSize: 17 * paper.sc
        font.weight: Font.Bold
        color: Press.ink
        wrapMode: Text.WordWrap
    }

    component Kicker: Text {
        font.family: Press.body
        font.pixelSize: 14 * paper.sc
        font.weight: Font.Bold
        font.letterSpacing: 2 * paper.sc
        font.capitalization: Font.AllUppercase
        color: Press.ink
    }

    component Rule: Rectangle {
        property real weight: 1
        height: Math.max(1, weight * paper.sc)
        color: Press.ink
    }

    Rectangle {
        anchors.fill: parent
        color: Press.paper
        opacity: paper.pageIn

        // A little shadow at the edges, as on a sheet held up.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Press.alpha("#6d6451", 0.12) }
                GradientStop { position: 0.12; color: "transparent" }
                GradientStop { position: 0.88; color: "transparent" }
                GradientStop { position: 1; color: Press.alpha("#6d6451", 0.16) }
            }
        }
    }

    LockInput {
        ctx: paper.ctx
        active: !paper.still
        onEscapePressed: paper.ctx.clearInput()
    }

    Item {
        id: page
        anchors.fill: parent
        opacity: paper.uiIn
        transform: Translate { x: paper.shakeX }

        // ── Masthead ─────────────────────────────────────────────────
        component Ear: Rectangle {
            id: ear
            property string label
            property string big
            property string small
            y: 40 * paper.sc
            width: 250 * paper.sc
            height: 112 * paper.sc
            color: "transparent"
            border.width: Math.max(1, paper.sc)
            border.color: Press.ink

            Column {
                anchors.centerIn: parent
                spacing: 1 * paper.sc

                Kicker {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ear.label
                    font.pixelSize: 11 * paper.sc
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ear.big
                    font.family: Press.masthead
                    font.pixelSize: 36 * paper.sc
                    font.weight: Font.Black
                    color: Press.ink
                }

                Body {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ear.small
                    font.pixelSize: 13 * paper.sc
                    font.italic: true
                    color: Press.inkSoft
                }
            }
        }

        Ear {
            x: paper.margin
            label: "The time"
            big: Press.time(paper.ctx.now)
            small: Press.edition(paper.ctx.now).toLowerCase()
        }

        Ear {
            x: paper.width - paper.margin - width
            readonly property real pct: Services.Battery.percentage
            label: "Power"
            big: Math.round(pct) + "%"
            small: Services.Battery.charging ? "charging, fair skies" : pct <= 20 ? "running low; bring a charger" : "on battery, holding steady"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30 * paper.sc
            text: "“All the News That Fits Your Screen”"
            font.family: Press.body
            font.pixelSize: 15 * paper.sc
            font.italic: true
            color: Press.inkSoft
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46 * paper.sc
            text: Press.paperName(paper.user)
            font.family: Press.masthead
            font.pixelSize: 108 * paper.sc
            font.weight: Font.Black
            color: Press.ink
        }

        Rule {
            x: paper.margin
            y: 190 * paper.sc
            width: paper.width - paper.margin * 2
            weight: 4
        }

        Rule {
            x: paper.margin
            y: 197 * paper.sc
            width: paper.width - paper.margin * 2
        }

        Item {
            x: paper.margin
            y: 203 * paper.sc
            width: paper.width - paper.margin * 2
            height: dateline.implicitHeight

            Kicker {
                text: Press.volume(paper.ctx.now) + "  ·  " + Press.number(paper.ctx.now)
                font.letterSpacing: 1 * paper.sc
            }

            Kicker {
                id: dateline
                anchors.horizontalCenter: parent.horizontalCenter
                text: Press.dateline(paper.ctx.now)
                font.letterSpacing: 1 * paper.sc
            }

            Kicker {
                anchors.right: parent.right
                text: "Price: one password"
                font.letterSpacing: 1 * paper.sc
            }
        }

        Rule {
            x: paper.margin
            y: 226 * paper.sc
            width: paper.width - paper.margin * 2
        }

        // ── The lead story ───────────────────────────────────────────
        Column {
            x: paper.margin
            y: 244 * paper.sc
            width: 1150 * paper.sc
            spacing: 6 * paper.sc

            Text {
                width: parent.width
                readonly property var c: paper.ctx
                text: (paper.granted ? paper.user + " is back"
                    : c.phase === "verifying" ? "Going to press…"
                    : c.denying ? "Wrong password; correction to follow"
                    : paper.halted ? "Presses halted"
                    : c.cells > 0 ? c.cells + (c.cells === 1 ? " keystroke" : " keystrokes") + " filed; " + paper.user + " expected back"
                    : "Desktop locked; " + paper.user + " away from desk").toUpperCase()
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 36 * paper.sc
                font.family: Press.headline
                font.pixelSize: 82 * paper.sc
                color: c.denying || paper.halted ? Press.spotInk : Press.ink
            }

            Text {
                width: parent.width
                readonly property var c: paper.ctx
                text: c.denying ? "Desk editors dispute the passcode filed moments ago; a correction will run in the next edition"
                    : paper.halted ? "Printing stops after too many corrections; presses to resume in " + (c.lockoutClock || "due course")
                    : c.cells > 0 ? "Sources close to the keyboard report typing; press Enter to go to print"
                    : "Screen secured at " + paper.lockedAtText + "; contents safe, officials say"
                elide: Text.ElideRight
                font.family: Press.masthead
                font.pixelSize: 26 * paper.sc
                font.italic: true
                color: Press.inkSoft
            }
        }

        // The caption under the photograph.
        Body {
            x: paper.photoSlot.x
            y: paper.photoSlot.y + paper.photoSlot.height + 8 * paper.sc
            width: paper.photoSlot.width
            text: "THE DESKTOP as it was left at " + paper.stop(paper.lockedAtText) + " Staff photograph."
            font.pixelSize: 14 * paper.sc
            font.italic: true
            color: Press.inkSoft
        }

        // Two more items under the photograph.
        Row {
            x: paper.photoSlot.x
            y: paper.photoSlot.y + paper.photoSlot.height + 40 * paper.sc
            width: 1150 * paper.sc
            spacing: 28 * paper.sc

            Column {
                width: (parent.width - parent.spacing) / 2
                spacing: 6 * paper.sc

                Rule {
                    width: parent.width
                }

                Head {
                    width: parent.width
                    text: Services.LockStats.bestKeysPerSec > 0
                        ? "Fastest fingers: " + Services.LockStats.bestKeysPerSec.toFixed(1) + " keys a second"
                        : "Typing speed yet to be recorded"
                }

                Body {
                    width: parent.width
                    horizontalAlignment: Text.AlignJustify
                    text: "The desk's record for a password typed start to finish stands" + (Services.LockStats.bestKeysPerSec >= 8 ? ", a feat the sports pages call lightning." : "; readers are invited to beat it.")
                    font.pixelSize: 15 * paper.sc
                }
            }

            Column {
                width: (parent.width - parent.spacing) / 2
                spacing: 6 * paper.sc

                Rule {
                    width: parent.width
                }

                Head {
                    width: parent.width
                    text: "Longest run: " + Services.LockStats.bestStreak + (Services.LockStats.bestStreak === 1 ? " day" : " days")
                }

                Body {
                    width: parent.width
                    horizontalAlignment: Text.AlignJustify
                    text: "The current streak of " + Services.LockStats.liveStreak + (Services.LockStats.liveStreak >= Services.LockStats.bestStreak && Services.LockStats.liveStreak > 0 ? " matches the record." : " has some way to go.")
                        + " Circulation, meanwhile, stands at " + Press.count(paper.shownXp) + "."
                    font.pixelSize: 15 * paper.sc
                }
            }
        }

        // Short items beside the photograph.
        Column {
            x: paper.photoSlot.x + paper.photoSlot.width + 28 * paper.sc
            y: paper.photoSlot.y
            width: 1150 * paper.sc - paper.photoSlot.width - 28 * paper.sc
            spacing: 8 * paper.sc

            readonly property real pct: Services.Battery.percentage

            Head {
                width: parent.width
                text: "Power " + (Services.Battery.charging ? "climbs" : "holds") + " at " + Math.round(parent.pct) + "%"
            }

            Body {
                width: parent.width
                horizontalAlignment: Text.AlignJustify
                text: "Reserves " + (Services.Battery.charging ? "were rising on mains power" : "held on battery") + " through the " + (paper.ctx.now.getHours() < 12 ? "morning" : paper.ctx.now.getHours() < 18 ? "afternoon" : "evening")
                    + ", according to figures released by the system. Analysts called the level " + (parent.pct > 60 ? "healthy." : parent.pct > 20 ? "adequate." : "a cause for concern.")
            }

            Rule {
                width: parent.width
            }

            Head {
                width: parent.width
                text: "Local user on " + Services.LockStats.liveStreak + "-day streak"
            }

            Body {
                width: parent.width
                horizontalAlignment: Text.AlignJustify
                text: "The desk's records show " + paper.user + " at work " + Services.LockStats.liveStreak + (Services.LockStats.liveStreak === 1 ? " day" : " days") + " running, with "
                    + Services.LockStats.unlocks + " returns on file and " + Services.LockStats.achievements.length + " of " + Services.LockStats.achievementDefs.length + " awards to date."
            }

            Rule {
                width: parent.width
            }

            Head {
                width: parent.width
                text: "Screen quiet for " + paper.away(paper.ctx.now.getTime() - paper.ctx.lockedAt)
            }

            Body {
                width: parent.width
                horizontalAlignment: Text.AlignJustify
                text: "No activity has been reported at the desk since " + paper.stop(paper.lockedAtText) + " Neighbours describe the screen as “locked tight.”" + (paper.ctx.capsLock ? " Caps lock is on, the desk warns." : "")
            }
        }

        // The byline, foot of the page.
        Rule {
            x: paper.margin
            y: paper.height - 60 * paper.sc
            width: 1150 * paper.sc
        }

        Row {
            x: paper.margin
            y: paper.height - 50 * paper.sc
            spacing: 14 * paper.sc

            // The correspondent's portrait, printed.
            Item {
                width: 30 * paper.sc
                height: 30 * paper.sc

                Item {
                    width: 0
                    height: 0
                    clip: true

                    Image {
                        id: avatar
                        width: 30 * paper.sc
                        height: 30 * paper.sc
                        source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                        sourceSize: Qt.size(120, 120)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                }

                ShaderEffect {
                    anchors.fill: parent
                    visible: avatar.status === Image.Ready

                    property variant source: avatar
                    property real itemWidth: width
                    property real itemHeight: height
                    property real press: 1
                    property real cell: Math.max(1.8, 2.6 * paper.sc)
                    property real fold: 0
                    property color paperColor: Press.paper

                    fragmentShader: Qt.resolvedUrl("../../../../shaders/desktop_press.frag.qsb")
                }
            }

            Body {
                anchors.verticalCenter: parent.verticalCenter
                text: "By " + paper.user + ", " + Press.career(paper.shownLevel) + "  ·  circulation " + Press.count(paper.shownXp)
                    + "  ·  " + Math.round(100 * Math.max(0, Math.min(1, (paper.shownXp - paper.levelFloor) / Math.max(1, paper.levelCeil - paper.levelFloor)))) + "% of the way to a raise"
                font.pixelSize: 15 * paper.sc
                font.italic: true
                color: paper.promote > 0 ? Press.spotInk : Press.inkSoft
            }
        }

        Body {
            x: paper.margin + 1150 * paper.sc - width
            y: paper.height - 48 * paper.sc
            text: "Continued on page A2"
            font.pixelSize: 14 * paper.sc
            font.italic: true
            color: Press.inkSoft
        }

        // ── The right-hand column ────────────────────────────────────
        Rule {
            x: paper.margin + 1176 * paper.sc
            y: 244 * paper.sc
            width: Math.max(1, paper.sc)
            height: paper.height - 244 * paper.sc - 40 * paper.sc
        }

        Column {
            id: side
            x: paper.margin + 1202 * paper.sc
            y: 244 * paper.sc
            width: paper.width - x - paper.margin
            spacing: 10 * paper.sc

            // Today's puzzle: the passcode, a square a keystroke.
            Kicker {
                text: "Today's puzzle"
                font.pixelSize: 17 * paper.sc
            }

            Rule {
                width: parent.width
                weight: 3
            }

            Flow {
                id: grid
                width: parent.width
                spacing: -Math.max(1, paper.sc)

                readonly property int squares: Math.max(12, Math.min(28, paper.ctx.cells + 4))

                Repeater {
                    model: grid.squares

                    Rectangle {
                        required property int index
                        readonly property bool filled: index < paper.ctx.cells
                        width: 38 * paper.sc
                        height: width
                        color: paper.ctx.denying && filled ? Press.alpha(Press.spotInk, 0.18) : "transparent"
                        border.width: Math.max(1, 1.5 * paper.sc)
                        border.color: Press.ink

                        Text {
                            x: 3 * paper.sc
                            y: 1 * paper.sc
                            visible: parent.index === 0
                            text: "1"
                            font.family: Press.body
                            font.pixelSize: 10 * paper.sc
                            color: Press.ink
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            visible: parent.filled
                            width: 11 * paper.sc
                            height: width
                            radius: width / 2
                            color: paper.ctx.denying ? Press.spotInk : Press.ink
                        }
                    }
                }
            }

            Body {
                width: parent.width
                readonly property var c: paper.ctx
                text: "1 Across. Your password (" + (c.cells > 0 ? c.cells : "?") + "). "
                    + (c.phase === "verifying" ? "Checking the answer…"
                    : c.message.length > 0 ? c.message
                    : c.capsLock ? "Mind the caps lock."
                    : c.cells > 0 ? "Press Enter to submit."
                    : "Type to fill in the squares.")
                font.pixelSize: 15 * paper.sc
                font.italic: true
            }

            // Corrections: the faillock lives.
            Item {
                width: 1
                height: 4 * paper.sc
            }

            Kicker {
                text: "Corrections"
                font.pixelSize: 17 * paper.sc
            }

            Rule {
                width: parent.width
                weight: 3
            }

            Body {
                width: parent.width
                readonly property var c: paper.ctx
                text: paper.halted ? "The desk has run out of corrections for now. Presses resume in " + (c.lockoutClock || "due course") + "."
                    : c.maxLives <= 0 ? "The desk takes corrections without limit."
                    : "The desk allows " + c.maxLives + " corrections; " + c.lives + (c.lives === 1 ? " remains." : " remain.")
                        + (c.lastLife ? " One more and printing stops for " + Math.round(c.unlockTime / 60) + " minutes." : "")
                font.pixelSize: 15 * paper.sc
                color: paper.halted || paper.ctx.lastLife ? Press.spotInk : Press.ink
            }

            Repeater {
                model: Math.min(paper.corrections, 3)

                Body {
                    required property int index
                    width: side.width
                    text: "— An earlier edition misprinted the password" + (index === 0 ? "." : ", again.")
                    font.pixelSize: 14 * paper.sc
                    font.italic: true
                    color: Press.inkSoft
                }
            }

            // On the radio.
            Item {
                width: 1
                height: 4 * paper.sc
            }

            Kicker {
                visible: Services.Media.activePlayer !== null
                text: "On the radio"
                font.pixelSize: 17 * paper.sc
            }

            Rule {
                visible: Services.Media.activePlayer !== null
                width: parent.width
                weight: 3
            }

            Row {
                visible: Services.Media.activePlayer !== null
                spacing: 10 * paper.sc

                Repeater {
                    // Static model: only the icon follows play/pause.
                    model: ["previous", "playPause", "next"]

                    Glyph {
                        id: mediaKey
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData === "playPause" ? (Services.Media.isPlaying ? "pause" : "play_arrow") : modelData === "previous" ? "skip_previous" : "skip_next"
                        filled: true
                        font.pixelSize: 20 * paper.sc
                        color: mediaArea.containsMouse ? Press.spotInk : Press.ink

                        MouseArea {
                            id: mediaArea
                            anchors.fill: parent
                            anchors.margins: -6 * paper.sc
                            enabled: !paper.still
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Media[mediaKey.modelData]()
                        }
                    }
                }

                Body {
                    anchors.verticalCenter: parent.verticalCenter
                    width: side.width - 110 * paper.sc
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: "“" + Services.Media.title + "”" + (Services.Media.artist ? ", " + Services.Media.artist : "")
                    font.pixelSize: 15 * paper.sc
                }
            }

            // Classifieds: the power actions, held to confirm.
            Item {
                width: 1
                height: 4 * paper.sc
            }

            Kicker {
                text: "Classifieds"
                font.pixelSize: 17 * paper.sc
            }

            Rule {
                width: parent.width
                weight: 3
            }

            Row {
                width: parent.width
                spacing: 10 * paper.sc

                Repeater {
                    model: [
                        { head: "SLEEP", body: "Screen seeks rest. Hold here.", act: "suspend" },
                        { head: "RESTART", body: "Fresh start wanted. Hold here.", act: "reboot" },
                        { head: "SHUT DOWN", body: "Closing for the night. Hold.", act: "poweroff" }
                    ]

                    Rectangle {
                        id: ad
                        required property var modelData
                        width: (side.width - 20 * paper.sc) / 3
                        height: 78 * paper.sc
                        color: adHold.containsMouse ? Press.alpha(Press.ink, 0.05) : "transparent"
                        border.width: Math.max(1, paper.sc)
                        border.color: Press.ink

                        // Held: the ad is inked in from the left.
                        Rectangle {
                            width: parent.width * adHold.progress
                            height: parent.height
                            color: Press.alpha(Press.spotInk, 0.25)
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 7 * paper.sc
                            spacing: 2 * paper.sc

                            Text {
                                text: ad.modelData.head
                                font.family: Press.headline
                                font.pixelSize: 20 * paper.sc
                                color: Press.ink
                            }

                            Body {
                                width: parent.width
                                text: ad.modelData.body
                                font.pixelSize: 12 * paper.sc
                                lineHeight: 1
                            }
                        }

                        HoldArea {
                            id: adHold
                            anchors.fill: parent
                            enabled: !paper.still
                            onConfirmed: paper.ctx[ad.modelData.act]()
                        }
                    }
                }
            }

            // Awards: the latest achievements.
            Item {
                width: 1
                height: 4 * paper.sc
            }

            Kicker {
                text: "Awards"
                font.pixelSize: 17 * paper.sc
            }

            Rule {
                width: parent.width
                weight: 3
            }

            Body {
                width: parent.width
                visible: Services.LockStats.unlockedDefs.length === 0
                text: "None yet. The committee is watching."
                font.pixelSize: 15 * paper.sc
                font.italic: true
            }

            Repeater {
                model: Services.LockStats.unlockedDefs.slice(0, 3)

                Body {
                    required property var modelData
                    width: side.width
                    text: "★ " + modelData.name + " — " + modelData.desc.charAt(0).toLowerCase() + modelData.desc.slice(1) + "."
                    font.pixelSize: 15 * paper.sc
                }
            }
        }

        // The corrections desk's stamp, and the halt.
        Text {
            x: side.x + side.width * 0.35
            y: 330 * paper.sc
            visible: paper.stamp > 0
            opacity: Math.min(1, paper.stamp * 2)
            scale: 1 + (1 - Math.min(1, paper.stamp * 2)) * 0.6
            rotation: -9
            text: "CORRECTION"
            font.family: Press.headline
            font.pixelSize: 58 * paper.sc
            font.letterSpacing: 4 * paper.sc
            color: Press.alpha(Press.spotInk, 0.8)
            style: Text.Outline
            styleColor: Press.alpha(Press.spotInk, 0.35)
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 60 * paper.sc
            visible: paper.halted
            rotation: -12
            text: "PRESSES HALTED"
            font.family: Press.headline
            font.pixelSize: 170 * paper.sc
            font.letterSpacing: 8 * paper.sc
            color: Press.alpha(Press.spotInk, 0.42)
        }
    }

    // ── The photograph: the desktop, printed ─────────────────────────
    CaptureImage {
        id: capture
        source: paper.shot
        imageWidth: paper.width
        imageHeight: paper.height
    }

    // Without a capture (a thumbnail), the paper prints the wallpaper.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: paper.width
            height: paper.height
            source: capture.ready ? "" : "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, paper.width), Math.max(1, paper.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    Item {
        id: photo
        readonly property real t: paper.photoIn
        readonly property Item picture: capture.ready ? capture.image : wallpaper
        x: paper.photoSlot.x * t
        y: paper.photoSlot.y * t
        width: paper.width + (paper.photoSlot.width - paper.width) * t
        height: paper.height + (paper.photoSlot.height - paper.height) * t
        visible: capture.ready || wallpaper.status === Image.Ready

        // The default shader draws `source` as it is.
        ShaderEffect {
            anchors.fill: parent
            property variant source: photo.picture
        }

        ShaderEffect {
            anchors.fill: parent
            opacity: Math.min(1, paper.photoIn * 1.4)

            property variant source: photo.picture
            property real itemWidth: width
            property real itemHeight: height
            property real press: 1
            property real cell: Math.max(2.2, 4.5 * paper.sc)
            property real fold: 0
            property color paperColor: Press.paper

            fragmentShader: Qt.resolvedUrl("../../../../shaders/desktop_press.frag.qsb")
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Math.max(1, paper.sc)
            border.color: Press.ink
            opacity: paper.photoIn
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - paper.pageIn
    }

    // ── EXTRA! ───────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: paper.extra > 0

        Rectangle {
            anchors.fill: parent
            color: Press.alpha("black", 0.35 * Math.min(1, paper.extra * 2))
        }

        Item {
            id: extraSheet
            anchors.centerIn: parent
            width: 1180 * paper.sc
            height: extraColumn.implicitHeight + 70 * paper.sc
            rotation: (1 - paper.extra) * 720
            scale: 0.08 + 0.92 * paper.extra

            Rectangle {
                x: 10 * paper.sc
                y: 10 * paper.sc
                width: parent.width
                height: parent.height
                color: Press.alpha("black", 0.4)
            }

            Rectangle {
                anchors.fill: parent
                color: Press.paper
            }

            Column {
                id: extraColumn
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34 * paper.sc
                width: parent.width - 80 * paper.sc
                spacing: 8 * paper.sc

                Item {
                    width: parent.width
                    height: extraWord.implicitHeight

                    Kicker {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18 * paper.sc
                        text: Press.paperName(paper.user)
                    }

                    Text {
                        id: extraWord
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "EXTRA!"
                        font.family: Press.headline
                        font.pixelSize: 170 * paper.sc
                        font.letterSpacing: 6 * paper.sc
                        color: Press.spotInk
                    }

                    Kicker {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18 * paper.sc
                        text: Press.time(paper.ctx.now)
                    }
                }

                Rule {
                    width: parent.width
                    weight: 4
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (paper.userCap + " is back!").toUpperCase()
                    font.family: Press.headline
                    font.pixelSize: 96 * paper.sc
                    color: Press.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Returns to the desk after " + paper.away(paper.reward ? paper.reward.awayMs : 0) + "; circulation up " + Math.round((paper.reward ? paper.reward.total : 0) * Math.min(1, paper.rewardIn * 1.3))
                    font.family: Press.masthead
                    font.pixelSize: 30 * paper.sc
                    font.italic: true
                    color: Press.inkSoft
                }

                Rule {
                    width: parent.width
                }

                Body {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    opacity: paper.rewardIn
                    visible: paper.reward !== null
                    text: paper.reward
                        ? paper.reward.lines.map(l => l.label.charAt(0) + l.label.slice(1).toLowerCase() + ", " + l.xp).join("; ")
                          + (paper.reward.multiplier > 1 ? "; on a streak, times " + paper.reward.multiplier.toFixed(2) : "") + "."
                        : ""
                    font.pixelSize: 18 * paper.sc
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: paper.promote > 0
                    opacity: paper.promote
                    text: "PROMOTED TO " + Press.career(paper.shownLevel).toUpperCase()
                    font.family: Press.masthead
                    font.pixelSize: 34 * paper.sc
                    font.weight: Font.Black
                    color: Press.spotInk
                }

                Repeater {
                    model: paper.reward ? paper.reward.achievements.slice(0, 3) : []

                    Body {
                        required property int index
                        required property var modelData
                        width: extraSheet.width - 80 * paper.sc
                        horizontalAlignment: Text.AlignHCenter
                        opacity: LockTheme.seg(paper.rewardIn, 0.2 + index * 0.18, 0.5 + index * 0.18)
                        text: "AWARD: " + modelData.name.toUpperCase() + " — " + modelData.desc
                        font.pixelSize: 17 * paper.sc
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: paper; property: "photoIn"; from: 0; to: 1; duration: 950; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation { target: paper; property: "pageIn"; from: 0; to: 1; duration: 650 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 820 }
            NumberAnimation { target: paper; property: "uiIn"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
        }
    }

    // The photograph grows back into the desktop: the last frame is the
    // desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: paper; property: "extra"; to: 0; duration: 380; easing.type: Easing.InCubic }
        NumberAnimation { target: paper; property: "uiIn"; to: 0; duration: 300 }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            ParallelAnimation {
                NumberAnimation { target: paper; property: "photoIn"; to: 0; duration: 850; easing.type: Easing.InOutCubic }
                NumberAnimation { target: paper; property: "pageIn"; to: 0; duration: 700 }
            }
        }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: paper; property: "stamp"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: paper; property: "stamp"; to: 0; duration: 400 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: paper; property: "shakeX"; to: -7 * paper.sc; duration: 40 }
            NumberAnimation { target: paper; property: "shakeX"; to: 5 * paper.sc; duration: 60 }
            NumberAnimation { target: paper; property: "shakeX"; to: 0; duration: 70 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: paper; property: "extra"; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 650 }
            NumberAnimation { target: paper; property: "rewardIn"; from: 0; to: 1; duration: 700 }
        }
    }

    SequentialAnimation {
        id: circulationFill
        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: paper
            property: "shownXp"
            to: paper.reward ? paper.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: paper; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: paper
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
