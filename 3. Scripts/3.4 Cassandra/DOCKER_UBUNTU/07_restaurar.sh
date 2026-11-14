#!/usr/bin/env bash
# Paso 7: prueba de restauracion. Restaura un respaldo en un keyspace NUEVO (mercado_restaurada),
# sin tocar el original, y compara las cantidades de filas.
# Uso: ./07_restaurar.sh <carpeta de ./respaldos>      (sin parametro, lista los respaldos)
# Con 3 nodos y RF = 3, cada nodo tiene todos los datos: basta restaurar desde los archivos del nodo 1.
source "$(dirname "$0")/lib.sh"
KS=mercado_cassandra; KR=mercado_restaurada
[ -n "$1" ] && [ -d "respaldos/$1" ] || { echo "Uso: $0 <carpeta de ./respaldos>"; ls respaldos 2>/dev/null; exit 1; }
TAG="$1"

echo "1) Creando el keyspace $KR con la misma estructura ..."
cql -e "DROP KEYSPACE IF EXISTS $KR;"
sed "s/$KS/$KR/g" "respaldos/$TAG/schema.cql" | docker compose exec -T -e U="$CASSANDRA_ADMIN_USER" -e P="$CASSANDRA_ADMIN_PASSWORD" cassandra-node1 sh -c 'cqlsh -u "$U" -p "$P"'

echo "2) Cargando los archivos del respaldo con sstableloader ..."
docker compose exec -T -e TAG="$TAG" -e KR="$KR" -e U="$CASSANDRA_ADMIN_USER" -e P="$CASSANDRA_ADMIN_PASSWORD" cassandra-node1 sh -c '
  rm -rf /tmp/restore && mkdir -p /tmp/restore/$KR
  for t in /respaldos/$TAG/node1/*/; do
    nombre=$(basename $t); mkdir -p /tmp/restore/$KR/$nombre; cp $t* /tmp/restore/$KR/$nombre/
    echo "   $nombre"
    sstableloader -d cassandra-node1 -u "$U" -pw "$P" /tmp/restore/$KR/$nombre >/dev/null 2>&1 || echo "   (revisar $nombre)"
  done'

echo; echo "3) Comparando cantidades (original vs restaurada)"
printf "%-40s %10s %10s %s\n" tabla original restaurada resultado
for t in pedidos_por_cliente pagos_por_metodo_dia recaudacion_por_metodo_mes movimientos_por_tipo_mes recepciones_por_centro; do
  a=$(cql --request-timeout=300 -e "SELECT COUNT(*) FROM $KS.$t;"  | sed -n '4p' | tr -d ' ')
  b=$(cql --request-timeout=300 -e "SELECT COUNT(*) FROM $KR.$t;" | sed -n '4p' | tr -d ' ')
  [ "$a" = "$b" ] && r=OK || r=FALLA
  printf "%-40s %10s %10s %s\n" "$t" "$a" "$b" "$r"
done
echo
echo "Para borrar la copia de prueba:  ./08_shell.sh   y dentro:  DROP KEYSPACE mercado_restaurada;"
