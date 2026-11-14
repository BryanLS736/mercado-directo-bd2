#!/usr/bin/env bash
# Paso 6: respaldo con mongodump (lee de un secundario, comprimido, en ./respaldos/). Conserva los últimos 7.
source "$(dirname "$0")/lib.sh"
read -r -s -p "Contraseña de respaldo_mongo: " PW; echo
SELLO=$(date +%Y%m%d_%H%M)
docker compose exec -T -e P="$PW" mongo1 sh -c \
  "mongodump --uri 'mongodb://mongo1:27017,mongo2:27017/?replicaSet=rs_mercado&readPreference=secondary' \
     -u respaldo_mongo -p \"\$P\" --authenticationDatabase admin \
     --db mercado_nosql --gzip --out /respaldos/mercado_nosql_$SELLO"
echo "Respaldo guardado en ./respaldos/mercado_nosql_$SELLO"
ls -1d respaldos/mercado_nosql_* 2>/dev/null | sort -r | tail -n +8 | while read -r v; do
  echo "Eliminando respaldo antiguo $v"; docker run --rm -v "$PWD/respaldos:/r" alpine rm -rf "/r/$(basename "$v")"; done
