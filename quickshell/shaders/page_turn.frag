#version 440
// The two sides of a turning leaf (see page_turn.vert): the page it was
// in front, the page it becomes behind, mirrored as a real leaf is, and
// the light across its curl. Ink stays the paper's own colour: the light
// is multiplied in, so dark pages darken and light ones grey.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in float vFacing;
layout(location = 2) in float vLight;

layout(location = 0) out vec4 fragColor;

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

layout(binding = 1) uniform sampler2D front;
layout(binding = 2) uniform sampler2D back;

void main() {
    float u = qt_TexCoord0.x;
    float v = qt_TexCoord0.y;
    bool facing = vFacing >= 0.0;
    // A right-hand page has its binding on its left; a left-hand page on
    // its right. The leaf's front is the page it was, its back the next.
    float fu = ubuf.dir > 0.0 ? u : 1.0 - u;
    vec4 c = facing ? texture(front, vec2(fu, v)) : texture(back, vec2(1.0 - fu, v));
    // The back of a leaf is a shade darker until it lies down.
    float light = vLight * (facing ? 1.0 : 0.94 + 0.06 * abs(vFacing));
    fragColor = vec4(c.rgb * light, c.a) * ubuf.qt_Opacity;
}
