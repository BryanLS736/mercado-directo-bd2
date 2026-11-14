#!/usr/bin/env bash
# Paso 5: crea los roles y usuarios (pide una contrasena por cada usuario) y muestra los permisos.
source "$(dirname "$0")/lib.sh"

echo "== 1) Roles de permisos (sin contrasena, no inician sesion) =="
cql -f /proyecto/cql/5_ROLES_Y_PERMISOS.cql

crear() {  # crear <usuario> <rol> <descripcion>
  local pw
  read -r -s -p "Contrasena para $1 ($3): " pw; echo
  [ -n "$pw" ] || { echo "  (omitido: contrasena vacia)"; return; }
  # la contrasena viaja por la entrada estandar: no queda en ningun archivo ni en la linea de comandos
  printf "CREATE ROLE IF NOT EXISTS %s WITH PASSWORD = '%s' AND LOGIN = true;\nGRANT %s TO %s;\n" "$1" "${pw//\'/\'\'}" "$2" "$1" | cql
}
echo; echo "== 2) Usuarios =="
crear app_servicio      rol_aplicacion "aplicacion Mercado Directo"
crear lectura_cassandra rol_lectura    "analistas, solo consulta"
for u in isabella jheremy misael bryan; do crear $u rol_lectura "desarrollador, solo lectura"; done

echo; echo "== 3) Resumen =="
cql -e "LIST ROLES;"
cql -e "LIST ALL PERMISSIONS OF rol_aplicacion;"
cql -e "LIST ALL PERMISSIONS OF rol_lectura;"
