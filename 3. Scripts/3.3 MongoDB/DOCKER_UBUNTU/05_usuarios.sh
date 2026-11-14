#!/usr/bin/env bash
# Paso 5: crea el rol y los usuarios (pide una contraseña por cada usuario) y verifica permisos.
source "$(dirname "$0")/lib.sh"
echo "== Crear rol y usuarios (escribe una contraseña para cada uno) =="
msh -t --file /proyecto/5_USUARIOS/5c_CREAR_USUARIOS_Y_ROLES.js
echo; echo "== Verificar permisos (pide la contraseña de app_servicio, lectura_mongo y respaldo_mongo) =="
docker compose exec mongo1 mongosh --quiet "$URI_RS" --file /proyecto/5_USUARIOS/5d_VERIFICAR_PERMISOS.js
