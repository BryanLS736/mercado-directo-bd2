#!/usr/bin/env bash
# Cancela el nodo 3 y levanta unicamente ese nodo (node1 y node2 no se tocan).
#   ./01b_reiniciar_nodo3.sh           reinicio normal (conserva sus datos)
#   ./01b_reiniciar_nodo3.sh limpio    ademas borra los datos de node3 (si quedo trabado en Joining)
set -e
source "$(dirname "$0")/lib.sh"

[ "$(docker compose ps --status running --format '{{.Name}}' | grep -cE 'cassandra-node[12]$')" = "2" ] \
  || { echo "node1 y node2 deben estar corriendo. Ejecuta primero ./01_levantar.sh"; exit 1; }

reiniciar_nodo3 "$1"

echo -n "Esperando a que node3 este en estado UN "
t=0
until [ "$(nodos_arriba)" = "3" ]; do
  echo -n "."; sleep 10; t=$((t+10))
  [ $t -ge 600 ] && { echo; echo "node3 sigue sin subir tras 10 min. Prueba: ./01b_reiniciar_nodo3.sh limpio"; exit 1; }
done
echo " listo"
docker compose exec -T cassandra-node1 nodetool status
