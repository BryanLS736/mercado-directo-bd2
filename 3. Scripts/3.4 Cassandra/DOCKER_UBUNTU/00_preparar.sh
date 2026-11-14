#!/usr/bin/env bash
# Paso 0: comprueba Docker y genera el archivo .env con una contrasena aleatoria para el administrador.
set -e
cd "$(dirname "$0")"
command -v docker >/dev/null || { echo "Docker no esta instalado. Ver la guia, seccion 4."; exit 1; }
docker compose version >/dev/null || { echo "Falta el plugin 'docker compose'. Ver la guia, seccion 4."; exit 1; }
command -v openssl >/dev/null || { echo "Falta openssl: sudo apt install -y openssl"; exit 1; }
if [ ! -f .env ]; then
  {
    echo "CASSANDRA_ADMIN_USER=dba_cassandra"
    echo "CASSANDRA_ADMIN_PASSWORD=$(openssl rand -hex 16)"
  } > .env
  chmod 600 .env
  echo "Creado .env  (contiene la contrasena de dba_cassandra; no lo subas a GitHub ni lo compartas)"
fi
mkdir -p respaldos
echo "Listo. Siguiente paso: ./01_levantar.sh"
