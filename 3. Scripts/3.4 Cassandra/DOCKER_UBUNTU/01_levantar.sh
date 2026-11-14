#!/usr/bin/env bash
# Paso 1: levanta los 3 nodos, crea al administrador, cierra la cuenta por defecto y abre DbGate.
set -e
source "$(dirname "$0")/lib.sh"

echo "Levantando los 3 nodos (los nodos entran uno a uno; tarda varios minutos) ..."
docker compose up -d cassandra-node1 cassandra-node2 cassandra-node3

echo -n "Esperando a que los 3 nodos esten en estado UN "
t=0
until [ "$(nodos_arriba)" = "3" ]; do
  echo -n "."; sleep 10; t=$((t+10))
  if [ $t -ge 1200 ]; then
    echo; echo "Pasaron 20 min sin tener los 3 nodos en UN. Revisa: docker compose ps  y  docker compose logs --tail=40 cassandra-node3"
    echo "No reinicies contenedores a mano mientras otro nodo se une. Si node3 quedo trabado: ./01b_reiniciar_nodo3.sh limpio"
    exit 1
  fi
done; echo " listo"

# Usuario inicial de Cassandra (cassandra / cassandra): es el predeterminado del producto y solo
# se usa aqui para crear al administrador propio; despues se deshabilita.
if docker compose exec -T cassandra-node1 cqlsh -u "$CASSANDRA_ADMIN_USER" -p "$CASSANDRA_ADMIN_PASSWORD" -e "SELECT now() FROM system.local" >/dev/null 2>&1; then
  echo "El administrador ${CASSANDRA_ADMIN_USER} ya existe."
else
  echo -n "Esperando a que se cree el usuario inicial "
  until docker compose exec -T cassandra-node1 cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local" >/dev/null 2>&1; do echo -n "."; sleep 5; done; echo " listo"
  echo "Creando al administrador ${CASSANDRA_ADMIN_USER} (SUPERUSER) ..."
  docker compose exec -T -e U="$CASSANDRA_ADMIN_USER" -e P="$CASSANDRA_ADMIN_PASSWORD" cassandra-node1 sh -c \
    'cqlsh -u cassandra -p cassandra -e "CREATE ROLE $U WITH PASSWORD = '"'"'$P'"'"' AND SUPERUSER = true AND LOGIN = true;"'
  echo "Deshabilitando el usuario inicial cassandra ..."
  cql -e "ALTER ROLE cassandra WITH SUPERUSER = false AND LOGIN = false;"
fi

echo "Replicando los datos de seguridad (system_auth) en los 3 nodos ..."
cql -e "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': 3};"
for n in 1 2 3; do docker compose exec -T cassandra-node$n nodetool repair -full system_auth >/dev/null 2>&1 || true; done

echo; echo "Estado del cluster:"
docker compose exec -T cassandra-node1 nodetool status

docker compose --profile ui up -d dbgate
echo
echo "DbGate: http://localhost:3000   (conexion: host cassandra-node1, DC datacenter1, usuario y contrasena de .env)"
echo "Siguiente paso: ./02_cargar_datos.sh"
