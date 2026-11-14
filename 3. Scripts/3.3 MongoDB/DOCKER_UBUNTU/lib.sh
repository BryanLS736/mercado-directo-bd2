#!/usr/bin/env bash
# Funciones comunes (las usan los demás scripts con: source ./lib.sh)
cd "$(dirname "${BASH_SOURCE[0]}")"
[ -f .env ] || { echo "Falta .env: ejecuta primero ./00_preparar.sh"; exit 1; }
set -a; source .env; set +a
URI_RS="mongodb://mongo1:27017,mongo2:27017/?replicaSet=rs_mercado"

# msh [-t] <args de mongosh>: mongosh autenticado como administrador dentro de mongo1.
# Usuario y contraseña viajan como variables de entorno del contenedor (no quedan en la línea de comandos).
msh() {
  local tty="-T"; [ "$1" = "-t" ] && { tty=""; shift; }
  docker compose exec $tty -e U="$MONGO_ADMIN_USER" -e P="$MONGO_ADMIN_PASSWORD" mongo1 \
    sh -c 'exec mongosh --quiet "$0" -u "$U" -p "$P" --authenticationDatabase admin "$@"' "$URI_RS" "$@"
}
