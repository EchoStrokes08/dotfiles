#version 300 es
// Escala de grises (luminancia Rec. 709: el ojo ve el verde más brillante que el azul)
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    float gris = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(gris), c.a);
}
