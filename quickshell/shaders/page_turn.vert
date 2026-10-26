#version 440
// A leaf of the customizer's book turning over (modules/customizer/
// PageTurn.qml). The leaf bends round the spine as a strip of constant
// curvature, so it stays the same length: `spineAngle` is how far it has
// turned at the binding, `edgeAngle` at its free edge (ahead of the
// binding while it's lifted, trailing as it falls). Seen from in front,
// what lifts towards you is drawn a little larger.
//
// The mesh's x runs from the binding (0) to the free edge (1), whichever
// way the leaf turns: `dir` is +1 for a right-hand page going over to the
// left, -1 for a left-hand page going back to the right.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

layout(location = 0) out vec2 qt_TexCoord0;
layout(location = 1) out float vFacing;
layout(location = 2) out float vLight;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float pageW;
    float pageH;
    float spineX;
    float dir;
    float spineAngle;
    float edgeAngle;
    float eye;
} ubuf;

void main() {
    float u = qt_MultiTexCoord0.x;
    float v = qt_MultiTexCoord0.y;
    float s = u * ubuf.pageW;
    float th = ubuf.spineAngle;
    float k = (ubuf.edgeAngle - ubuf.spineAngle) / ubuf.pageW;
    float X;
    float Z;
    if (abs(k) < 1e-5) {
        X = s * cos(th);
        Z = s * sin(th);
    } else {
        X = (sin(th + k * s) - sin(th)) / k;
        Z = (cos(th) - cos(th + k * s)) / k;
    }
    float phi = th + k * s;
    float p = ubuf.eye / max(1.0, ubuf.eye - Z);
    float x = ubuf.spineX + ubuf.dir * X * p;
    float y = ubuf.pageH * 0.5 + (v - 0.5) * ubuf.pageH * p;

    qt_TexCoord0 = vec2(u, v);
    vFacing = cos(phi);
    // Lit from in front and a little above: brightest facing you, dimmer
    // edge on, with a gleam where the curl turns towards the light.
    vLight = 0.66 + 0.34 * abs(cos(phi)) + 0.1 * pow(max(0.0, sin(2.0 * phi)), 6.0);
    gl_Position = ubuf.qt_Matrix * vec4(x, y, 0.0, 1.0);
}
