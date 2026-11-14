#!/usr/bin/env bash
# Paso 2: crea las 4 colecciones con validadores e índices y carga los datos (.jsonl).
set -e
source "$(dirname "$0")/lib.sh"

echo "Creando colecciones, validadores e índices ..."
msh --file /proyecto/1_CREAR_COLECCIONES.js

for c in seguimiento_ruta calificaciones incidencias perfil_agricultor; do
  echo "Cargando $c ..."
  docker compose exec -T -e P="$MONGO_ADMIN_PASSWORD" mongo1 sh -c \
    "mongoimport --uri '$URI_RS' -u '$MONGO_ADMIN_USER' -p \"\$P\" --authenticationDatabase admin \
       --db mercado_nosql --collection $c --file /proyecto/datos/$c.jsonl --numInsertionWorkers 4"
done

echo; echo "Conteos (deben ser 6446, 33077, 6625 y 2331):"
msh --eval 'const b = db.getSiblingDB("mercado_nosql");
  b.getCollectionNames().sort().forEach(c => print(c + ": " + b[c].countDocuments()))'
