#!/usr/bin/env bash
# Abre el menú genérico de Quickshell (Menu.qml) con las opciones que le pases en JSON:
#   menu.sh "Título" '[{"icono":983324,"texto":"Hacer algo","cmd":"comando"}, …]'
# icono = código del glifo Nerd Font en decimal. Lo usan movil.sh y modulos/sesiones.lua.
# El JSON viaja en base64 porque «qs ipc call» parte los argumentos por las comas.
qs ipc call menu json "$1" "$(printf '%s' "$2" | base64 -w0)"
