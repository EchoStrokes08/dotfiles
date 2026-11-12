#!/usr/bin/env bash
# Instalación por usuario; no necesita sudo. Requiere internet.
set -euo pipefail
base="$HOME/.local/share/brujula/navegador"
if [[ "${1:-}" == --simular ]]; then
    printf 'Crearía %s/venv, instalaría Playwright y descargaría Chromium.\n' "$base"
    exit 0
fi
umask 077
mkdir -p "$base"
python3 -m venv "$base/venv"
"$base/venv/bin/python" -m pip install 'playwright>=1.56,<2'
"$base/venv/bin/python" -m playwright install chromium
"$base/venv/bin/python" - <<'PY'
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.set_content('<title>Prueba del navegador</title><button>Listo</button>')
    page.get_by_role('button', name='Listo').click()
    assert page.title() == 'Prueba del navegador'
    browser.close()
PY
touch "$base/listo"
printf 'Navegador listo. Abre Super+O y pide: busca en internet las noticias de hoy.\n'
