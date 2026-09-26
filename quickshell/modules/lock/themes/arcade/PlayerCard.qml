pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services as Services
import qs.modules.lock

// The player's profile: avatar inside a segmented XP ring, name, level and
// rank, XP bar, daily streak and lives. playReward() animates the XP gained by
// an unlock and fires the level-up effects when the bar crosses a level.
HudPanel {
    id: card

    required property LockContext ctx
    property real sc: 1

    // Bound to the stored XP until a reward animation takes it over.
    property real displayXp: Services.LockStats.xp
    readonly property int displayLevel: Services.LockStats.levelFor(displayXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(displayLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(displayLevel + 1)
    readonly property real progress: Math.max(0, Math.min(1, (displayXp - levelFloor) / Math.max(1, levelCeil - levelFloor)))
    property bool rewarding: false
    property int _shownLevel: 0

    implicitWidth: 640 * sc
    implicitHeight: 158 * sc
    cut: 16 * sc

    // Rewind to the XP before the unlock (the stored value has already
    // moved on), then fill the bar once ACCESS GRANTED has landed.
    function playReward(r) {
        rewarding = true;
        displayXp = r.xpBefore;
        xpAnim.to = r.xpAfter;
        xpFill.restart();
    }

    function _levelUp() {
        levelUpFx.restart();
        const cx = ringBox.x + ringBox.width / 2;
        const cy = ringBox.y + ringBox.height / 2;
        for (let i = 0; i < 18; i++) {
            const a = Math.random() * Math.PI * 2;
            const v = (60 + Math.random() * 90) * card.sc;
            sparkComp.createObject(fx, {
                x: cx,
                y: cy,
                vx: Math.cos(a) * v,
                vy: Math.sin(a) * v - 20 * card.sc,
                color: LockTheme.gold,
                life: 700 + Math.random() * 300
            });
        }
    }

    Component.onCompleted: _shownLevel = displayLevel
    onDisplayLevelChanged: {
        if (rewarding && _shownLevel > 0 && displayLevel > _shownLevel)
            _levelUp();
        _shownLevel = displayLevel;
    }

    SequentialAnimation {
        id: xpFill

        PauseAnimation { duration: 250 }
        NumberAnimation {
            id: xpAnim
            target: card
            property: "displayXp"
            duration: 750
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: card; property: "rewarding"; value: false }
    }

    Component {
        id: sparkComp
        Spark {}
    }

    // ── Avatar + XP ring ─────────────────────────────────────────────
    Item {
        id: ringBox
        x: 20 * card.sc
        anchors.verticalCenter: parent.verticalCenter
        width: 124 * card.sc
        height: width

        Repeater {
            model: 40

            Item {
                id: seg
                required property int index
                readonly property bool lit: index < Math.round(card.progress * 40)

                anchors.fill: parent
                rotation: index * 9

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 3 * card.sc
                    height: 9 * card.sc
                    radius: 1
                    color: seg.lit ? LockTheme.gold : LockTheme.alpha(LockTheme.ink, 0.16)
                }
            }
        }

        Item {
            id: avatar
            anchors.centerIn: parent
            width: 94 * card.sc
            height: width

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            Image {
                id: avatarImg
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: avatarImg
                visible: avatarImg.status === Image.Ready
                maskEnabled: true
                maskSource: avatarMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: avatarImg.status !== Image.Ready
                color: LockTheme.panelHi

                Glyph {
                    anchors.centerIn: parent
                    text: "person"
                    filled: true
                    font.pixelSize: 48 * card.sc
                    color: LockTheme.inkDim
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: LockTheme.alpha(LockTheme.accent, 0.85)
            }
        }

        // Level-up shockwave
        Rectangle {
            id: burst
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 3 * card.sc
            border.color: LockTheme.gold
            opacity: 0
        }
    }

    // ── Name, rank, XP ───────────────────────────────────────────────
    Column {
        id: info
        anchors.left: ringBox.right
        anchors.leftMargin: 22 * card.sc
        anchors.right: levelBox.left
        anchors.rightMargin: 16 * card.sc
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7 * card.sc

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.ctx.userName.toUpperCase()
            font.family: LockTheme.display
            font.pixelSize: 26 * card.sc
            color: LockTheme.ink
        }

        Row {
            spacing: 8 * card.sc

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7 * card.sc
                height: width
                rotation: 45
                color: LockTheme.accent
            }

            Text {
                text: Services.LockStats.rankFor(card.displayLevel)
                font.family: LockTheme.mono
                font.pixelSize: 12 * card.sc
                font.weight: Font.Bold
                font.letterSpacing: 4 * card.sc
                color: LockTheme.accent
            }
        }

        // XP bar with 10% ticks
        Item {
            width: parent.width
            height: 10 * card.sc

            Rectangle {
                anchors.fill: parent
                color: LockTheme.alpha(LockTheme.ink, 0.1)
            }

            Rectangle {
                width: parent.width * card.progress
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: LockTheme.alpha(LockTheme.gold, 0.55) }
                    GradientStop { position: 1; color: LockTheme.gold }
                }
            }

            Repeater {
                model: 9

                Rectangle {
                    required property int index
                    x: (index + 1) * parent.width / 10 - 1
                    width: 2
                    height: parent.height
                    color: LockTheme.alpha(LockTheme.base, 0.7)
                }
            }
        }

        Item {
            width: parent.width
            height: xpText.implicitHeight

            Text {
                id: xpText
                text: Math.floor(card.displayXp - card.levelFloor).toLocaleString(Qt.locale(), "f", 0)
                      + " / " + (card.levelCeil - card.levelFloor).toLocaleString(Qt.locale(), "f", 0) + " XP"
                font.family: LockTheme.mono
                font.pixelSize: 11 * card.sc
                font.letterSpacing: 1.5 * card.sc
                color: LockTheme.inkDim
            }

            Row {
                anchors.right: parent.right
                spacing: 14 * card.sc

                // Daily streak
                Row {
                    spacing: 3 * card.sc

                    Glyph {
                        text: "local_fire_department"
                        filled: true
                        font.pixelSize: 15 * card.sc
                        color: Services.LockStats.liveStreak >= 2 ? LockTheme.gold : LockTheme.inkFaint
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Services.LockStats.liveStreak > 0 ? Services.LockStats.liveStreak + "-DAY STREAK" : "NO STREAK"
                        font.family: LockTheme.mono
                        font.pixelSize: 11 * card.sc
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5 * card.sc
                        color: Services.LockStats.liveStreak >= 2 ? LockTheme.gold : LockTheme.inkDim
                    }
                }

                // Lives
                Row {
                    visible: card.ctx.maxLives > 0
                    spacing: 1 * card.sc

                    Repeater {
                        model: Math.min(card.ctx.maxLives, 5)

                        Glyph {
                            id: heart
                            required property int index
                            readonly property bool full: index < card.ctx.lives

                            text: "favorite"
                            filled: full
                            font.pixelSize: 15 * card.sc
                            color: full ? LockTheme.danger : LockTheme.inkFaint

                            onFullChanged: if (!full) lost.restart()

                            SequentialAnimation {
                                id: lost
                                NumberAnimation { target: heart; property: "scale"; to: 1.8; duration: 110; easing.type: Easing.OutQuad }
                                NumberAnimation { target: heart; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBounce }
                            }
                        }
                    }

                    Text {
                        visible: card.ctx.maxLives > 5
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.ctx.lives + "/" + card.ctx.maxLives
                        font.family: LockTheme.mono
                        font.pixelSize: 11 * card.sc
                        color: LockTheme.danger
                    }
                }
            }
        }
    }

    // ── Level ────────────────────────────────────────────────────────
    Column {
        id: levelBox
        anchors.right: parent.right
        anchors.rightMargin: 26 * card.sc
        anchors.verticalCenter: parent.verticalCenter
        spacing: -4 * card.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "LEVEL"
            font.family: LockTheme.mono
            font.pixelSize: 11 * card.sc
            font.weight: Font.Bold
            font.letterSpacing: 4 * card.sc
            color: LockTheme.inkDim
        }

        Text {
            id: levelNum
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.displayLevel
            font.family: LockTheme.display
            font.pixelSize: 54 * card.sc
            color: LockTheme.gold
        }
    }

    // ── Level-up effects ─────────────────────────────────────────────
    Item {
        id: fx
        anchors.fill: parent
    }

    // Badge that pops up straddling the card's top edge.
    HudPanel {
        id: levelUpBadge
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        width: levelUpLabel.implicitWidth + 40 * card.sc
        height: 36 * card.sc
        cut: 9 * card.sc
        fill: LockTheme.panelHi
        stroke: LockTheme.alpha(LockTheme.gold, 0.55)
        accent: LockTheme.gold
        accentLength: 24 * card.sc
        opacity: 0
        scale: 0.6

        Text {
            id: levelUpLabel
            anchors.centerIn: parent
            text: "LEVEL UP  ·  " + Services.LockStats.rankFor(card.displayLevel)
            font.family: LockTheme.display
            font.pixelSize: 17 * card.sc
            font.letterSpacing: 3 * card.sc
            color: LockTheme.gold
        }
    }

    ParallelAnimation {
        id: levelUpFx

        SequentialAnimation {
            NumberAnimation { target: levelNum; property: "scale"; to: 1.6; duration: 140; easing.type: Easing.OutQuad }
            NumberAnimation { target: levelNum; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutElastic }
        }
        SequentialAnimation {
            PropertyAction { target: burst; property: "scale"; value: 0.8 }
            PropertyAction { target: burst; property: "opacity"; value: 1 }
            ParallelAnimation {
                NumberAnimation { target: burst; property: "scale"; to: 2.1; duration: 650; easing.type: Easing.OutCubic }
                NumberAnimation { target: burst; property: "opacity"; to: 0; duration: 650; easing.type: Easing.InQuad }
            }
        }
        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation { target: levelUpBadge; property: "opacity"; to: 1; duration: 160 }
                NumberAnimation { target: levelUpBadge; property: "scale"; from: 0.6; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
            PauseAnimation { duration: 1100 }
            NumberAnimation { target: levelUpBadge; property: "opacity"; to: 0; duration: 300 }
        }
    }
}
