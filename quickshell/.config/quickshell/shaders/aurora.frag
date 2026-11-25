// Aurora: el fondo generativo (FondoGenerativo.qml). Ruido fractal deformado con los colores del tema,
// cortinas de luz arriba que laten con la música, estrellas de noche y un tono frío cuando llueve.
// Lo compila FondoGenerativo.qml con qsb a ~/.cache/quickshell/ (no se guardan binarios en el repo).
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float tiempo;          // s (se para cuando el escritorio está tapado)
    float energia;         // 0–1: los graves de lo que suena
    float noche;           // 0 = día · 1 = noche
    float lluvia;          // 0–1
    float desplazamiento;  // la cámara entre espacios
    vec2 resolucion;       // px lógicos
    vec4 color1;           // acento
    vec4 color2;           // acento2
    vec4 color3;           // un tercero de la serie
    vec4 fondo;
};

float hash(vec2 p) {                     // hash12 de Dave Hoskins: sin filas ni patrones
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    mat2 giro = mat2(0.8, -0.6, 0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        v += a * ruido(p);
        p = giro * p * 2.02;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 px = qt_TexCoord0 * resolucion;
    vec2 uv = qt_TexCoord0;
    float aspecto = resolucion.x / max(resolucion.y, 1.0);
    vec2 p = vec2(uv.x * aspecto, uv.y) * 1.15 + vec2(desplazamiento, 0.0);
    float t = tiempo;

    // Ruido deformado sobre sí mismo (domain warping): un fluido grande que se mueve muy despacio
    vec2 q = vec2(fbm(p + vec2(0.0, 0.02 * t)), fbm(p + vec2(5.2, 1.3) - 0.015 * t));
    vec2 r = vec2(fbm(p + 2.0 * q + vec2(1.7, 9.2) + 0.03 * t), fbm(p + 2.0 * q + vec2(8.3, 2.8) - 0.025 * t));
    float f = fbm(p + 2.5 * r);

    // Nebulosa: cuerpo del tercer color, velos del segundo y vetas brillantes del acento
    vec3 col = fondo.rgb;
    col = mix(col, color3.rgb * 0.42, smoothstep(0.35, 0.9, f) * 0.55);
    col = mix(col, color2.rgb * 0.4, smoothstep(0.3, 0.85, q.y * r.x * 1.7) * 0.4);
    float veta = smoothstep(0.55, 0.95, f * length(q) * 1.25);
    col += color1.rgb * veta * veta * 0.32;
    // Más saturado y más oscuro abajo, donde van las ventanas
    float g0 = dot(col, vec3(0.3, 0.59, 0.11));
    col = mix(vec3(g0), col, 1.4);
    col *= mix(1.0, 0.6, smoothstep(0.35, 1.0, uv.y));

    // Aurora: una cinta ondulada con el borde de abajo brillante y rayos que suben y se desvanecen;
    // aparece por tramos que se desplazan
    float x = uv.x * aspecto + desplazamiento * 0.6;
    float onda = sin(x * 1.7 + fbm(vec2(x * 0.9, t * 0.05)) * 4.0 + t * 0.08) + 0.5 * sin(x * 3.9 - t * 0.11);
    float borde = 0.34 + 0.06 * onda;
    float d = borde - uv.y;                                  // > 0: por encima del borde
    float cortina = smoothstep(-0.05, 0.02, d) * exp(-max(d, 0.0) * 8.0);
    float rayos = 0.1 + 1.1 * pow(ruido(vec2(x * 30.0, t * 0.2)), 2.2) * (0.6 + 0.8 * ruido(vec2(x * 7.0, t * 0.1)));
    float tramos = smoothstep(0.32, 0.68, fbm(vec2(x * 0.6 + t * 0.02, 3.0)));
    float aurora = cortina * rayos * tramos * (0.7 + 0.8 * energia) * mix(0.8, 1.3, noche);
    vec3 tonoAurora = mix(color2.rgb, color1.rgb, smoothstep(0.0, 0.25, d));   // el borde de un color, la cima de otro
    col += tonoAurora * aurora * 0.9;

    // Estrellas de noche (detrás de la aurora), titilando
    vec2 celda = floor(px / 2.0);
    float h = hash(celda + floor(desplazamiento * 60.0));
    float estrella = step(0.997, h) * (0.5 + 0.5 * sin(t * (1.2 + h * 3.0) + h * 40.0));
    col += vec3(estrella) * noche * (1.0 - min(1.0, aurora * 2.0)) * (1.0 - smoothstep(0.25, 0.8, uv.y)) * 0.9;

    // Día / noche y lluvia
    col *= mix(1.0, 0.7, noche);
    float gris = dot(col, vec3(0.3, 0.59, 0.11));
    col = mix(col, vec3(gris) * vec3(0.82, 0.92, 1.1), lluvia * 0.55);

    // Viñeta y un poco de grano para que el degradado no haga bandas
    vec2 dv = uv - 0.5;
    col *= 1.0 - 0.45 * dot(dv, dv) * 1.8;
    col += (hash(px + fract(t)) - 0.5) / 160.0;

    fragColor = vec4(max(col, 0.0), 1.0) * qt_Opacity;
}
