#!/usr/bin/env bash
# Comprueba que puede y que NO puede hacer cada usuario (pide la contrasena de app_servicio y lectura_cassandra).
source "$(dirname "$0")/lib.sh"
KS=mercado_cassandra
prueba() {  # prueba <usuario> <contrasena> <sentencia>
  local out
  out=$(docker compose exec -T -e U="$1" -e P="$2" cassandra-node1 sh -c 'cqlsh -u "$U" -p "$P" -e "$0"' "$3" 2>&1)
  if echo "$out" | grep -qiE 'Unauthorized|has no .* permission|Forbidden'; then echo DENEGADO
  elif echo "$out" | grep -qiE 'error|Failed|AuthenticationFailed'; then echo "ERROR"
  else echo PERMITIDO; fi
}
printf "%-24s %-16s %-16s\n" "operacion" "app_servicio" "lectura_cassandra"
read -r -s -p "Contrasena de app_servicio: " PA; echo
read -r -s -p "Contrasena de lectura_cassandra: " PL; echo
INS="INSERT INTO $KS.recepciones_por_centro (centro_acopio_id, estado, fecha_recepcion, recepcion_id) VALUES (999998, 'REGISTRADA', toTimestamp(now()), 1)"
fila() { printf "%-24s %-16s %-16s\n" "$1" "$(prueba app_servicio "$PA" "$2")" "$(prueba lectura_cassandra "$PL" "$2")"; }
fila "leer pagos"          "SELECT * FROM $KS.pagos_por_metodo_dia LIMIT 1"
fila "insertar recepcion"     "$INS"
fila "borrar recepcion"       "DELETE FROM $KS.recepciones_por_centro WHERE centro_acopio_id = 999998"
fila "insertar recaudacion" "INSERT INTO $KS.recaudacion_por_metodo_mes (metodo_pago, mes, total_pagos, monto_total) VALUES ('PRUEBA', '2026-01', 1, 1)"
fila "crear tabla"         "CREATE TABLE $KS.tabla_prueba (id int PRIMARY KEY)"
fila "crear usuario"       "CREATE ROLE usuario_prueba WITH LOGIN = false"
echo
echo "Esperado:  app_servicio: lee/inserta/borra recepciones = PERMITIDO; recaudacion (tabla calculada), crear tabla, crear usuario = DENEGADO"
echo "           lectura_cassandra: solo leer = PERMITIDO; todo lo demas = DENEGADO"
cql -e "DELETE FROM $KS.recepciones_por_centro WHERE centro_acopio_id = 999998;" >/dev/null 2>&1
