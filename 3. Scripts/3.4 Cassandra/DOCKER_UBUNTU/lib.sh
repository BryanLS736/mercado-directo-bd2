#!/usr/bin/env bash
# Funciones comunes (las usan los demas scripts con: source ./lib.sh)
cd "$(dirname "${BASH_SOURCE[0]}")"
[ -f .env ] || { echo "Falta .env: ejecuta primero ./00_preparar.sh"; exit 1; }
set -a; source .env; set +a

# cql [-t] <args de cqlsh>: cqlsh autenticado como administrador dentro de cassandra-node1.
# Usuario y contrasena viajan como variables de entorno del contenedor (no quedan en la linea de comandos del anfitrion).
cql() {
  local tty="-T"; [ "$1" = "-t" ] && { tty=""; shift; }
  docker compose exec $tty -e U="$CASSANDRA_ADMIN_USER" -e P="$CASSANDRA_ADMIN_PASSWORD" cassandra-node1 \
    sh -c 'exec cqlsh -u "$U" -p "$P" "$@"' _ "$@"
}

# nodos_arriba: cuantos nodos aparecen como UN (Up/Normal) en nodetool status
nodos_arriba() {
  docker compose exec -T cassandra-node1 nodetool status 2>/dev/null | grep -c '^UN' || true
}

# reiniciar_nodo3 [limpio]: cancela (detiene) SOLO cassandra-node3 y lo vuelve a levantar solo.
# --no-deps evita que compose toque node1/node2 (siguen corriendo). Con "limpio" borra ademas
# el volumen de node3 (util si quedo a medias en estado Joining y no avanza).
reiniciar_nodo3() {
  echo "Cancelando cassandra-node3 ..."
  docker compose stop cassandra-node3 || true
  if [ "$1" = "limpio" ]; then
    echo "Borrando los datos locales de node3 (volumen cassandra_data_3) ..."
    docker compose rm -f cassandra-node3 >/dev/null 2>&1 || true
    docker volume rm "$(docker compose config --format json | grep -o '"name": *"[^"]*cassandra_data_3"' | head -1 | sed 's/.*: *"//;s/"$//')" 2>/dev/null \
      || docker volume rm mercado_cassandra_cassandra_data_3 2>/dev/null || true
  fi
  echo "Levantando unicamente cassandra-node3 ..."
  docker compose up -d --no-deps cassandra-node3
}
