#!/usr/bin/env bash
# Paso 0: comprueba Docker y genera el keyFile y el archivo .env con contraseñas aleatorias.
set -e
cd "$(dirname "$0")"
command -v docker >/dev/null || { echo "Docker no está instalado. Ver la guía, sección 3."; exit 1; }
docker compose version >/dev/null || { echo "Falta el plugin 'docker compose'. Ver la guía, sección 3."; exit 1; }
command -v openssl >/dev/null || { echo "Falta openssl: sudo apt install -y openssl"; exit 1; }

if [ ! -f mongo.key ]; then
  openssl rand -base64 756 > mongo.key      # clave compartida entre los nodos del replica set
  chmod 400 mongo.key
  echo "Creado mongo.key"
fi
if [ ! -f .env ]; then
  {
    echo "MONGO_ADMIN_USER=dba_mongo"
    echo "MONGO_ADMIN_PASSWORD=$(openssl rand -hex 16)"
  } > .env
  chmod 600 .env
  echo "Creado .env  (contiene la contraseña de dba_mongo; no lo subas a GitHub ni lo compartas)"
fi
mkdir -p respaldos
echo "Listo. Siguiente paso: ./01_levantar.sh"
