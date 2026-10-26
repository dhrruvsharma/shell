import QtQuick

// Text set on the book's pages: the theme's body face in its ink.
Text {
    color: BookStyle.ink
    font.family: BookStyle.body
    font.pixelSize: BookStyle.bodySize
    textFormat: Text.PlainText
    lineHeight: 1.12
}
