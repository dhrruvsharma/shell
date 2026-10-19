import QtQuick
import qs.components
import qs.colors
import qs.services as Services
import qs.Core

BarPill {
    text: tempIcon + " " + Services.System.temp + "°C"
    textColor: tempColor

    property int t: Services.System.temp

    property string tempIcon: {
        if (t >= 85) return Icons.fire
        if (t >= 50) return Icons.temperatureMedium
        return Icons.temperature
    }

    property color tempColor: t >= 85 ? Colors.error : Services.BarSettings.ink
}
