#!/usr/bin/env bash
# Calendario de la waybar: clic en la hora = abrir, otro clic = cerrar.
# Flechas < > del calendario para cambiar mes/año. Esc o "Cancelar" también lo cierran.
if pkill -f 'zenity --calendar --title=Calendario'; then
    exit 0
fi
zenity --calendar --title=Calendario --text="" >/dev/null 2>&1 &
