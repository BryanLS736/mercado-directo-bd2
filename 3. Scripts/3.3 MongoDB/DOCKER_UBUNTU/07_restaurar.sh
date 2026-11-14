#!/usr/bin/env bash
# Paso 7: restaura un respaldo en una base de prueba (mercado_restaurada) y compara con la original.
# Uso: ./07_restaurar.sh mercado_nosql_20260101_1200
source "$(dirname "$0")/lib.sh"
[ -n "$1" ] || { echo "Uso: $0 <carpeta de ./respaldos>"; ls respaldos; exit 1; }
docker compose exec -T -e P="$MONGO_ADMIN_PASSWORD" mongo1 sh -c \
  "mongorestore --uri '$URI_RS' -u '$MONGO_ADMIN_USER' -p \"\$P\" --authenticationDatabase admin --gzip \
     --nsInclude 'mercado_nosql.*' --nsFrom 'mercado_nosql.*' --nsTo 'mercado_restaurada.*' --drop /respaldos/$1"
msh --file /proyecto/6_RESPALDO/6c_VERIFICAR_RESTAURACION.js
echo
echo "Para borrar la copia de prueba:"
echo "  ./08_shell.sh   y dentro:  db.getSiblingDB('mercado_restaurada').dropDatabase()"
