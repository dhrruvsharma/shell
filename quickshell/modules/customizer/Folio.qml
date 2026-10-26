import QtQuick

// A page's number at its foot, in Roman numerals set the theme's way
// ("— iv —", "PAGE IV", "॥ iv ॥" …).
BookText {
    property int number: 1

    text: BookStyle.folio(number)
    font.family: BookStyle.body
    font.pixelSize: 13
    font.letterSpacing: 1.6
    color: BookStyle.inkSoft
    horizontalAlignment: Text.AlignHCenter
}
