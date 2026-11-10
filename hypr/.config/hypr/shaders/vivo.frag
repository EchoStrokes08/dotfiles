#version 300 es
// Colores vivos: más saturación (x1.35) y un poco más de contraste
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    float gris = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 saturado = mix(vec3(gris), c.rgb, 1.35);
    vec3 contraste = (saturado - 0.5) * 1.06 + 0.5;
    fragColor = vec4(clamp(contraste, 0.0, 1.0), c.a);
}
