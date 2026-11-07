pragma ComponentBehavior: Bound
import QtQuick

// A screen's windows, in layout coordinates, in the room they have: past the
// screen's edges, where a scrolling layout's columns go, as far as the next
// screen. Those columns aren't on it, and they'd hide it.
Item {
    id: room

    // { x, y, w, h }: ShareView.roomOf().
    required property var bounds
    required property var windows
    // The view.
    required property var owner

    // The window at a point in `other`'s coordinates, or null.
    function windowAt(other, px, py) {
        const p = mapFromItem(other, px, py);
        if (p.x < 0 || p.y < 0 || p.x >= width || p.y >= height)
            return null;
        for (let i = rep.count - 1; i >= 0; i--) {
            const item = rep.itemAt(i) as ShareWindow;
            if (item?.holds(other, px, py))
                return item;
        }
        return null;
    }

    function windowFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const item = rep.itemAt(i) as ShareWindow;
            if (item?.info.id === id)
                return item;
        }
        return null;
    }

    x: bounds.x
    y: bounds.y
    width: bounds.w
    height: bounds.h
    clip: true

    Repeater {
        id: rep

        model: room.windows

        ShareWindow {
            required property var modelData

            info: modelData
            x: modelData.x - room.bounds.x
            y: modelData.y - room.bounds.y
            width: modelData.w
            height: modelData.h
            radius: room.owner.session.rounding
            line: 2.5 / room.owner.fit
            reach: 50
            hot: room.owner.hotKey === "window:" + modelData.id
            dim: room.owner.lit(modelData) ? 0 : room.owner.dim
            live: room.owner.seg(0.1, 0.6, room.owner.intro)
        }
    }
}
