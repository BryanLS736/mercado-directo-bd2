// =====================================================================
// 5a_CREAR_ADMIN.js  -  Mercado Directo (MongoDB)
// Crea el primer usuario (administrador) mientras el servidor todavía
// NO exige autenticación. Equivale a "diego / dba_role" en PostgreSQL y
// a "rol_dba" en Oracle.
//
// Ejecutar conectado al PRIMARIO (nodo 1):
//     mongosh --port 27017 --file 5a_CREAR_ADMIN.js
// La contraseña se pide por pantalla: no queda escrita en ningún archivo.
// =====================================================================

db.getSiblingDB('admin').createUser({
  user: 'dba_mongo',
  pwd: passwordPrompt(),
  roles: [{ role: 'root', db: 'admin' }]
});
print('Usuario dba_mongo creado. Siguiente paso: 5b_ACTIVAR_AUTENTICACION.ps1');
