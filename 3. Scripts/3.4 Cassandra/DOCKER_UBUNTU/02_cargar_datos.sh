#!/usr/bin/env bash
# Paso 2: crea el keyspace y las 5 tablas, y carga los datos (COPY de los CSV).
set -e
source "$(dirname "$0")/lib.sh"

echo "Creando keyspace y tablas ..."
cql -f /proyecto/cql/1_CREAR_KEYSPACE_Y_TABLAS.cql
echo "Cargando CSV con COPY (tarda un par de minutos) ..."
cql -f /proyecto/cql/2_CARGAR_DATOS.cql

echo; echo "Conteos esperados: 85200, 85722, 51, 37042 y 30611"
for t in pedidos_por_cliente pagos_por_metodo_dia recaudacion_por_metodo_mes movimientos_por_tipo_mes recepciones_por_centro; do
  echo -n "$t: "; cql --request-timeout=300 -e "SELECT COUNT(*) FROM mercado_cassandra.$t;" | sed -n '4p'
done
