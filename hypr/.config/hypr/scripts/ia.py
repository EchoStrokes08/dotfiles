#!/usr/bin/env python3
"""Asistente local (ollama, sin internet). Lo usa el panel de Quickshell (IA.qml), que muestra
la respuesta según va saliendo.
    ia.py <accion> [pregunta…]      el texto sobre el que trabajar llega por la entrada estándar
Acciones: resumir · corregir · explicar · traducir · mejorar · preguntar
Modelo: ~/.config/ia/modelo (una línea, p. ej. «gemma3:4b»; otros: ollama pull <modelo>).
"""
import json, sys, urllib.request
from pathlib import Path

URL = "http://127.0.0.1:11434/api/chat"
try:
    MODELO = (Path.home() / ".config/ia/modelo").read_text().strip() or "gemma3:4b"
except OSError:
    MODELO = "gemma3:4b"

SISTEMA = ("Eres un asistente integrado en el escritorio de un estudiante de ingeniería en Colombia. "
           "Responde siempre en español (salvo que te pidan traducir), claro y breve, sin introducciones "
           "ni despedidas. Usa Markdown sencillo: listas y **negritas** cuando ayuden.")
ACCIONES = {
    "resumir":   "Resume el siguiente texto en pocas viñetas con lo esencial:\n\n{t}",
    "corregir":  "Corrige la ortografía, la gramática y la puntuación del siguiente texto, sin cambiar su sentido "
                 "ni su tono. Devuelve SOLO el texto corregido, sin comentarios:\n\n{t}",
    "mejorar":   "Reescribe el siguiente texto para que sea más claro y esté mejor redactado, con el mismo "
                 "significado y un tono natural. Devuelve SOLO el texto reescrito:\n\n{t}",
    "explicar":  "Explica de forma sencilla qué significa lo siguiente. Si es un error o un comando de Linux, "
                 "di qué lo causa y cómo se arregla:\n\n{t}",
    "traducir":  "Traduce el siguiente texto: si está en español, al inglés; si está en otro idioma, al español. "
                 "Devuelve SOLO la traducción:\n\n{t}",
}

accion = sys.argv[1] if len(sys.argv) > 1 else "preguntar"
pregunta = " ".join(sys.argv[2:]).strip()
# Límites medidos en este equipo (solo CPU: ~43 tokens/s leyendo, ~8 tokens/s escribiendo):
# 32 000 caracteres ≈ 8 000 tokens ≈ 3-4 min de lectura; caben en un contexto de 16 384 con sitio para la respuesta.
MAX_CARACTERES = 32000
CONTEXTO = 16384
texto = "" if sys.stdin.isatty() else sys.stdin.read().strip()[:MAX_CARACTERES]

if accion in ACCIONES:
    if not texto:
        sys.exit("No hay texto: selecciona o copia algo primero.")
    mensaje = ACCIONES[accion].format(t=texto)
else:
    if not pregunta:
        sys.exit("Escribe una pregunta.")
    mensaje = pregunta + (f"\n\nTexto al que me refiero:\n\n{texto}" if texto else "")

cuerpo = json.dumps({"model": MODELO, "stream": True, "keep_alive": "10m", "options": {"num_ctx": CONTEXTO},
                     "messages": [{"role": "system", "content": SISTEMA}, {"role": "user", "content": mensaje}]}).encode()
try:
    with urllib.request.urlopen(urllib.request.Request(URL, cuerpo, {"Content-Type": "application/json"}), timeout=900) as r:
        for linea in r:
            trozo = json.loads(linea).get("message", {}).get("content", "")
            if trozo:
                sys.stdout.write(trozo); sys.stdout.flush()
except OSError as e:
    sys.exit(f"No pude hablar con ollama ({e}). ¿Está activo?  systemctl status ollama")
