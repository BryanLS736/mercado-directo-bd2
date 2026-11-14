#!/usr/bin/env bash
# Abre mongosh interactivo (autenticado) sobre mercado_nosql.
source "$(dirname "$0")/lib.sh"
docker compose exec -it -e U="$MONGO_ADMIN_USER" -e P="$MONGO_ADMIN_PASSWORD" mongo1 \
  sh -c 'exec mongosh "$0" -u "$U" -p "$P" --authenticationDatabase admin' "mongodb://mongo1:27017,mongo2:27017/mercado_nosql?replicaSet=rs_mercado"
