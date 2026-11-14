#!/usr/bin/env bash
# Paso 6: respaldo de mercado_cassandra con "nodetool snapshot" (copia instantanea de los archivos SSTable).
# Guarda, en ./respaldos/<etiqueta>/ :  schema.cql (estructura) y los archivos de cada nodo (node1, node2, node3).
# Conserva los ultimos 7 respaldos.
source "$(dirname "$0")/lib.sh"
KS=mercado_cassandra
TAG="${KS}_$(date +%Y%m%d_%H%M)"

echo "Guardando la estructura (schema.cql) ..."
mkdir -p "respaldos/$TAG"
cql -e "DESCRIBE KEYSPACE $KS" > "respaldos/$TAG/schema.cql"

for n in 1 2 3; do
  echo "Nodo $n: snapshot $TAG ..."
  docker compose exec -T cassandra-node$n nodetool snapshot -t "$TAG" "$KS" >/dev/null
  docker compose exec -T -e TAG="$TAG" -e N="$n" -e KS="$KS" cassandra-node$n sh -c '
    cd /var/lib/cassandra/data/$KS &&
    for d in */; do
      d=${d%/}; t=${d%-*}
      mkdir -p /respaldos/$TAG/node$N/$t
      cp $d/snapshots/$TAG/* /respaldos/$TAG/node$N/$t/ 2>/dev/null
      rm -f /respaldos/$TAG/node$N/$t/manifest.json /respaldos/$TAG/node$N/$t/schema.cql
    done'
done
echo "Respaldo guardado en ./respaldos/$TAG"
echo "Archivos por tabla en el nodo 1:"
for t in respaldos/$TAG/node1/*; do echo "  $(basename $t): $(ls $t | wc -l) archivos, $(du -sh $t | cut -f1)"; done

# Los snapshots ocupan espacio en cada nodo: se eliminan (la copia ya esta en ./respaldos)
for n in 1 2 3; do docker compose exec -T cassandra-node$n nodetool clearsnapshot -t "$TAG" >/dev/null; done

ls -1d respaldos/${KS}_* 2>/dev/null | sort -r | tail -n +8 | while read -r v; do
  echo "Eliminando respaldo antiguo $v"; docker run --rm -v "$PWD/respaldos:/r" alpine rm -rf "/r/$(basename "$v")"; done
