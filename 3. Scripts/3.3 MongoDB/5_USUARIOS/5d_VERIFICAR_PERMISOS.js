// =====================================================================
// 5d_VERIFICAR_PERMISOS.js  -  Mercado Directo (MongoDB)
// Comprueba qué puede y qué NO puede hacer cada usuario.
// Pide la contraseña de app_servicio, lectura_mongo y respaldo_mongo.
//
//     mongosh "mongodb://localhost:27017/?replicaSet=rs_mercado" --file 5d_VERIFICAR_PERMISOS.js
//
// Resultado esperado:
//   operación                           app_servicio  lectura_mongo  respaldo_mongo
//   leer incidencias                    PERMITIDO     PERMITIDO      PERMITIDO (el rol backup necesita leer para respaldar)
//   insertar incidencia                 PERMITIDO     DENEGADO       DENEGADO
//   actualizar incidencia               PERMITIDO     DENEGADO       DENEGADO
//   borrar incidencia                   DENEGADO      DENEGADO       DENEGADO
//   insertar calificación               PERMITIDO     DENEGADO       DENEGADO
//   actualizar calificación             DENEGADO      DENEGADO       DENEGADO
//   crear un usuario                    DENEGADO      DENEGADO       DENEGADO
// =====================================================================

const BD = 'mercado_nosql';
const prueba = (f) => { try { f(); return 'PERMITIDO'; } catch (e) { return e.codeName === 'Unauthorized' ? 'DENEGADO' : 'ERROR: ' + e.message.slice(0, 40); } };

function sesion(usuario) {
  const c = new Mongo('mongodb://localhost:27017/?replicaSet=rs_mercado');
  print('Contraseña de ' + usuario + ':');
  c.getDB('admin').auth(usuario, passwordPrompt());
  return c.getDB(BD);
}

const nuevaInc = (n) => ({ _id: 'INC-98' + n, tipo: 'PAGO_ANULADO', severidad: 'BAJA',
  origen: { sistema: 'oracle', tabla: 'pago', id: 1 }, fecha: new Date(), estado: 'ABIERTA',
  historial: [{ fecha: new Date(), estado: 'REGISTRADA' }] });
const nuevaCal = (n) => ({ _id: 9000000 + n, pedido_id: 9000000 + n, fecha: new Date(),
  cliente: { cliente_id: 1 }, agricultor: { agricultor_id: 1 }, producto: { producto_id: 1 },
  puntuacion: 5, aspectos: { frescura: 5, puntualidad: 5, empaque: 5 } });

const resultados = [];
['app_servicio', 'lectura_mongo', 'respaldo_mongo'].forEach((u, i) => {
  const bd = sesion(u);
  resultados.push({ usuario: u,
    leer_incidencias: prueba(() => bd.incidencias.findOne()),
    insertar_incidencia: prueba(() => bd.incidencias.insertOne(nuevaInc('000' + i))),
    actualizar_incidencia: prueba(() => bd.incidencias.updateOne({ _id: 'INC-000001' }, { $set: { descripcion: 'prueba permisos' } })),
    borrar_incidencia: prueba(() => bd.incidencias.deleteOne({ _id: 'INC-98000' + i })),
    insertar_calificacion: prueba(() => bd.calificaciones.insertOne(nuevaCal(i))),
    actualizar_calificacion: prueba(() => bd.calificaciones.updateOne({ _id: 1 }, { $set: { comentario: 'x' } })),
    crear_usuario: prueba(() => bd.getSiblingDB('admin').createUser({ user: 'x', pwd: 'x', roles: [] })) });
});
console.table(resultados);
print('Los documentos de prueba (INC-98xxxx y calificaciones 9000000+) los elimina el administrador:');
print("  db.getSiblingDB('mercado_nosql').incidencias.deleteMany({_id:/^INC-98/}); db.getSiblingDB('mercado_nosql').calificaciones.deleteMany({_id:{$gte:9000000}})");
