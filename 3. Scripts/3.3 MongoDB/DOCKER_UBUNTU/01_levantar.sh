#!/usr/bin/env bash
# Paso 1: levanta los 3 nodos, inicia el replica set, crea al administrador y abre Mongo Express.
set -e
source "$(dirname "$0")/lib.sh"

echo "Levantando los 3 nodos ..."
docker compose up -d mongo1 mongo2 mongo3

echo -n "Esperando a mongo1 "
until docker compose exec -T mongo1 mongosh --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; do
  echo -n "."; sleep 2
done; echo " listo"

# Si ya hay administrador, el replica set ya fue iniciado: no repetir.
if msh --eval "db.hello().ok" >/dev/null 2>&1; then
  echo "El replica set ya estaba iniciado."
else
  echo "Iniciando el replica set rs_mercado ..."
  docker compose exec -T mongo1 mongosh --quiet --eval '
    try { rs.initiate({ _id: "rs_mercado", members: [
      { _id: 0, host: "mongo1:27017", priority: 2 },
      { _id: 1, host: "mongo2:27017", priority: 1 },
      { _id: 2, host: "mongo3:27017", priority: 0, hidden: true, secondaryDelaySecs: 60 } ] }); }
    catch (e) { print("rs.initiate: " + e.message); }
    for (let i = 0; i < 60 && !db.hello().isWritablePrimary; i++) sleep(1000);
    print("primario: " + db.hello().isWritablePrimary);'
  echo "Creando al administrador ${MONGO_ADMIN_USER} (rol root) ..."
  docker compose exec -T -e U="$MONGO_ADMIN_USER" -e P="$MONGO_ADMIN_PASSWORD" mongo1 mongosh --quiet --eval '
    db.getSiblingDB("admin").createUser({ user: process.env.U, pwd: process.env.P, roles: ["root"] });
    print("administrador creado");'
fi

echo "Estado del replica set:"
msh --eval 'console.table(rs.status().members.map(m => ({ nodo: m.name, estado: m.stateStr, salud: m.health })))'

docker compose --profile ui up -d mongo-express
echo
echo "Mongo Express: http://localhost:8081   (usuario y contraseña: los de .env)"
echo "Siguiente paso: ./02_cargar_datos.sh"
