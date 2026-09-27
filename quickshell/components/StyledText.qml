import QtQuick
import qs.colors
import qs.services as Services

// Base text element for the shell. The colour is defaulted, and the family
// follows the desktop theme (the default font when none is on); size stays
// whatever Text gives you. Set font.family to opt out.
Text {
    color: Colors.on_surface
    font.family: Services.DesktopTheme.font || Qt.application.font.family
}
