#version 300 es
// Invertido: invierte la luminosidad y conserva el tono (invertir y girar el color 180°)
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    vec3 inv = 1.0 - c.rgb;
    // girar el tono 180° alrededor del eje gris: 2·media − color
    float media = (inv.r + inv.g + inv.b) / 3.0;
    vec3 girado = clamp(2.0 * media - inv, 0.0, 1.0);
    // el blanco puro pasaría a negro puro: se deja en el fondo Ayu, que cansa menos
    fragColor = vec4(mix(vec3(0.055, 0.078, 0.098), vec3(0.90, 0.88, 0.81), dot(girado, vec3(0.2126, 0.7152, 0.0722))) * 0.35 + girado * 0.65, c.a);
}
