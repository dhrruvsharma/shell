import qs.components
import qs.services as Services

BarPill {
    text: " " + Math.round(Services.Volume.volume * 100) + "%"
    horizontalPadding: 20
    maxWidth: 160
}
