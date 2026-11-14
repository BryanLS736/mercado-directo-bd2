// =====================================================================
// 5c_CREAR_USUARIOS_Y_ROLES.js  -  Mercado Directo (MongoDB)
// Administración de usuarios: un rol propio para la aplicación, roles
// integrados para lectura, respaldo y monitoreo, y los usuarios del equipo.
//
// Ejecutar como administrador (pide su contraseña y luego la de cada usuario nuevo):
//     mongosh "mongodb://localhost:27017/?replicaSet=rs_mercado" -u dba_mongo --authenticationDatabase admin --file 5c_CREAR_USUARIOS_Y_ROLES.js
//
// EQUIVALENCIA CON LOS OTROS GESTORES
//   MongoDB                 PostgreSQL        Oracle
//   dba_mongo (root)        diego / dba_role  rol_dba
//   rol_aplicacion_mongo    app_role          rol_aplicacion
//   read (integrado)        dev_role / lectura_role
//   backup (integrado)      -                 -
//
// PRINCIPIO: mínimo privilegio. Nadie, salvo el administrador, puede borrar
// documentos (igual que en PostgreSQL, donde ningún rol tiene DELETE).
// =====================================================================

const admin = db.getSiblingDB('admin');
const BD = 'mercado_nosql';
const sobre = (coleccion) => ({ resource: { db: BD, collection: coleccion } });

// ---------------------------------------------------------------------
// 1) Rol propio para la aplicación (permisos exactos por colección)
// ---------------------------------------------------------------------
admin.createRole({
  role: 'rol_aplicacion_mongo',
  privileges: [
    { ...sobre('seguimiento_ruta'),   actions: ['find', 'insert', 'update'] },   // registra eventos de ruta
    { ...sobre('calificaciones'),     actions: ['find', 'insert'] },             // las calificaciones no se editan
    { ...sobre('incidencias'),        actions: ['find', 'insert', 'update'] },   // se actualiza el estado/historial
    { ...sobre('perfil_agricultor'),  actions: ['find'] }                        // solo lectura (se recalcula aparte)
  ],
  roles: []
});

// ---------------------------------------------------------------------
// 2) Usuarios del sistema
// ---------------------------------------------------------------------
function crear(usuario, roles, descripcion) {
  print('Contraseña para ' + usuario + ' (' + descripcion + '):');
  admin.createUser({ user: usuario, pwd: passwordPrompt(), roles: roles });
}

crear('app_servicio', [{ role: 'rol_aplicacion_mongo', db: 'admin' }], 'aplicación Mercado Directo');
crear('lectura_mongo', [{ role: 'read', db: BD }], 'analistas, solo consulta');
crear('respaldo_mongo', [{ role: 'backup', db: 'admin' }], 'cuenta de respaldos');
crear('monitor_mongo', [{ role: 'clusterMonitor', db: 'admin' }], 'monitoreo del replica set');

// ---------------------------------------------------------------------
// 3) Usuarios del equipo (desarrolladores: solo lectura, como dev_role en PostgreSQL)
// ---------------------------------------------------------------------
['isabella', 'jheremy', 'misael', 'bryan'].forEach(u =>
  crear(u, [{ role: 'read', db: BD }], 'desarrollador, solo lectura'));

// ---------------------------------------------------------------------
// 4) Resumen
// ---------------------------------------------------------------------
console.table(admin.getUsers().users.map(u => ({
  usuario: u.user, roles: u.roles.map(r => r.role).join(', ') })));
