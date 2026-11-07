import QtQuick
import qs.modules.control

// The levels: the control centre's (the output's volume, its glyph mutes,
// its chevron opens the outputs to choose from; the brightness; the night
// light's warmth while it's on).
PaneSection {
    title: EdgeWords.word("sound")
    preferredWidth: 316

    Levels {
        width: parent.width
    }
}
