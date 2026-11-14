MathJax 3.2.2 · Apache-2.0 (LICENSE).
Motor SVG local para agente_render.py; no CDN ni peticiones durante el renderizado.
fuente.cjs es el punto de entrada; render.cjs contiene únicamente sus dependencias.
Reconstrucción desde un directorio temporal:

    npm install --ignore-scripts mathjax-full@3.2.2 esbuild@0.25.12
    ./node_modules/.bin/esbuild fuente.cjs --bundle --platform=node --minify --outfile=render.cjs

Se incluyen base, AMS, newcommand y boldsymbol. No se incluyen extensiones para HTML,
recursos externos ni carga dinámica. El SVG se rasteriza con librsvg a 3x porque Qt
Svg Tiny omite operadores que MathJax dibuja con elementos SVG anidados.
