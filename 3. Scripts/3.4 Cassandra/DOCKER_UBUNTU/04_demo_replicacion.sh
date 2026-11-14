#!/usr/bin/env bash
# Paso 4: demuestra la replicacion asincrona y la tolerancia a fallos (tarda unos minutos).
#   1) estado del cluster y de que nodos guardan una fila (RF = 3)
#   2) escritura en el nodo 1 y lectura desde los otros nodos
#   3) se detiene el nodo 2, se escribe con el nodo caido y se vuelve a encender:
#      el dato llega solo (hinted handoff).
source "$(dirname "$0")/lib.sh"
KS=mercado_cassandra
T="DEMO_REPLICA_$(date +%H%M%S)"
n() { docker compose exec -T -e U="$CASSANDRA_ADMIN_USER" -e P="$CASSANDRA_ADMIN_PASSWORD" "cassandra-node$1" sh -c 'exec cqlsh -u "$U" -p "$P" "$@"' _ "${@:2}"; }

echo "=== 1) Nodos del cluster (UN = Up/Normal) ==="
docker compose exec -T cassandra-node1 nodetool status
echo; echo "=== Replicacion del keyspace ==="
cql -e "SELECT keyspace_name, replication FROM system_schema.keyspaces WHERE keyspace_name = '$KS';"

echo; echo "=== 2) Escribir en el NODO 1 (CONSISTENCY ONE: responde cuando 1 replica confirma) ==="
n 1 -e "CONSISTENCY ONE; INSERT INTO $KS.recepciones_por_centro (centro_acopio_id, estado, fecha_recepcion, recepcion_id, centro_nombre, observaciones) VALUES (999, 'REGISTRADA', toTimestamp(now()), 1, 'PRUEBA', 'prueba de replicacion');"
echo "Nodos que guardan el centro 999 (deben ser los 3, porque RF = 3):"
docker compose exec -T cassandra-node1 nodetool getendpoints $KS recepciones_por_centro 999
sleep 3
for k in 1 2 3; do
  echo "--- lectura en el nodo $k (CONSISTENCY ONE) ---"
  n $k -e "CONSISTENCY ONE; SELECT centro_acopio_id, recepcion_id, estado, observaciones FROM $KS.recepciones_por_centro WHERE centro_acopio_id = 999;"
done

echo; echo "=== 3) Tolerancia a fallos: se DETIENE el nodo 2 ==="
docker stop cassandra-node2 >/dev/null
sleep 20
docker compose exec -T cassandra-node1 nodetool status | grep -E '^(UN|DN)'
echo "Escribiendo en el nodo 1 con el nodo 2 caido (CONSISTENCY QUORUM: basta con 2 de 3) ..."
n 1 -e "CONSISTENCY QUORUM; INSERT INTO $KS.recepciones_por_centro (centro_acopio_id, estado, fecha_recepcion, recepcion_id, centro_nombre, observaciones) VALUES (999, 'REGISTRADA', toTimestamp(now()), 2, 'PRUEBA', 'escrito con el nodo 2 caido');"
n 1 -e "CONSISTENCY QUORUM; SELECT centro_acopio_id, recepcion_id, observaciones FROM $KS.recepciones_por_centro WHERE centro_acopio_id = 999;"

echo; echo "=== Se REINICIA el nodo 2 (recibe lo que se perdio mediante 'hinted handoff') ==="
docker start cassandra-node2 >/dev/null
echo -n "Esperando a que el nodo 2 vuelva "
until [ "$(nodos_arriba)" = "3" ]; do echo -n "."; sleep 10; done; echo " listo"
sleep 30
echo "--- lectura en el nodo 2 (CONSISTENCY ONE) ---"
n 2 -e "CONSISTENCY ONE; SELECT centro_acopio_id, recepcion_id, observaciones FROM $KS.recepciones_por_centro WHERE centro_acopio_id = 999;"

echo; echo "=== Limpieza de la fila de prueba ==="
cql -e "DELETE FROM $KS.recepciones_por_centro WHERE centro_acopio_id = 999;"
echo "Listo. Si en el nodo 2 faltara la fila 1, ejecuta:  docker compose exec cassandra-node2 nodetool repair $KS"
