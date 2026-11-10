#!/usr/bin/env bash
# Gestor de contraseñas para el lanzador (SUPER+R → «p nombre»). Funciona con el que tengas:
#   · rbw  = cliente de Bitwarden (tu bóveda de siempre, también en el móvil y Firefox)
#   · pass = archivos cifrados con GPG en ~/.password-store (todo local)
#   claves.sh clave|usuario <rbw|pass> <nombre> [usuario]  -> lo ESCRIBE donde esté el cursor
#   claves.sh desbloquear     -> pide la contraseña maestra de Bitwarden
#   claves.sh configurar      -> guía para dejarlo listo
# La contraseña nunca pasa por el portapapeles (no queda en el historial): se teclea con wtype.
case "$1" in
    clave|usuario)
        tipo=$2 nombre=$3 usuario=$4
        if [ "$1" = usuario ]; then texto=$usuario
        elif [ "$tipo" = rbw ]; then texto=$(rbw get "$nombre" ${usuario:+"$usuario"})
        else texto=$(pass show "$nombre" | head -1); fi
        [ -z "$texto" ] && { notify-send -a Contraseñas "No pude leer «$nombre»"; exit 1; }
        sleep 0.35                       # que el lanzador se cierre y el foco vuelva a la ventana
        wtype -- "$texto" ;;
    desbloquear)
        rbw unlock && notify-send -a Contraseñas -u low "Bitwarden desbloqueado" "Vuelve a buscar con «p nombre»" ;;
    configurar)
        cat <<'GUIA'

  Gestor de contraseñas en el lanzador
  ────────────────────────────────────
  Opción A · Bitwarden (recomendada si ya lo usas o quieres las claves también en el móvil)
      rbw config set email TU_CORREO
      rbw config set pinentry pinentry-gnome3
      rbw login          (te pide la contraseña maestra)
      rbw sync
    Cuenta gratis en https://bitwarden.com · importa las de Firefox desde su web.

  Opción B · pass (todo en este equipo, cifrado con GPG)
      gpg --full-generate-key
      pass init TU_CORREO
      pass insert correo/gmail

  Después: SUPER+R, escribe «p » y el nombre. Enter escribe la contraseña donde esté el cursor.

GUIA
        read -rp "  Enter para cerrar " _ ;;
    *)  echo "uso: claves.sh clave|usuario <rbw|pass> <nombre> [usuario] | desbloquear | configurar"; exit 1 ;;
esac
