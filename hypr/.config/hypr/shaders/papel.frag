#version 300 es
// Papel: gris teñido de sepia y con menos contraste (el blanco baja a crema, el negro sube a marrón)
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    float gris = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 tinta = vec3(0.16, 0.13, 0.10);   // el negro
    vec3 hoja  = vec3(0.96, 0.90, 0.78);   // el blanco
    vec3 sepia = mix(tinta, hoja, gris);
    fragColor = vec4(mix(sepia, c.rgb, 0.15), c.a);   // deja un 15 % del color original
}
