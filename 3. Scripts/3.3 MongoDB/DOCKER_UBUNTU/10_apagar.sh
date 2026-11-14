#!/usr/bin/env bash
# ./10_apagar.sh         detiene los contenedores (los datos se conservan)
# ./10_apagar.sh borrar  elimina contenedores Y datos (vuelve a empezar desde cero)
cd "$(dirname "$0")"
if [ "$1" = "borrar" ]; then
  read -r -p "Esto BORRA todos los datos de MongoDB. Escribe SI para continuar: " r
  [ "$r" = "SI" ] && docker compose --profile ui down -v
else
  docker compose --profile ui stop
fi
