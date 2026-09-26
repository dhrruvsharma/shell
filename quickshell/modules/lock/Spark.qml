import QtQuick

// A single particle: flies from where it was created by (vx, vy) while it
// spins and fades, then destroys itself. Spawned in bursts with createObject.
Rectangle {
    id: spark

    property real vx: 0
    property real vy: 0
    property real spin: 180
    property int life: 520
    property real _x0: 0
    property real _y0: 0

    width: 4
    height: 4
    antialiasing: true

    Component.onCompleted: {
        _x0 = x;
        _y0 = y;
        fly.start();
    }

    ParallelAnimation {
        id: fly
        onFinished: spark.destroy()

        NumberAnimation { target: spark; property: "x"; from: spark._x0; to: spark._x0 + spark.vx; duration: spark.life; easing.type: Easing.OutCubic }
        NumberAnimation { target: spark; property: "y"; from: spark._y0; to: spark._y0 + spark.vy; duration: spark.life; easing.type: Easing.OutQuad }
        NumberAnimation { target: spark; property: "rotation"; from: 0; to: spark.spin; duration: spark.life }
        NumberAnimation { target: spark; property: "opacity"; from: 1; to: 0; duration: spark.life; easing.type: Easing.InQuad }
        NumberAnimation { target: spark; property: "scale"; from: 1.2; to: 0.4; duration: spark.life }
    }
}
