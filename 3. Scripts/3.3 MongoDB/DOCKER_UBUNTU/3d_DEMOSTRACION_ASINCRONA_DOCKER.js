// =====================================================================
// 3d_DEMOSTRACION_ASINCRONA_DOCKER.js  -  Mercado Directo (MongoDB)
// Demuestra en vivo que la replicación es asíncrona.
//
// Ejecutar conectado al replica set (con las colecciones ya cargadas):
//     mongosh "mongodb://localhost:27017/?replicaSet=rs_mercado" --file 3d_DEMOSTRACION_ASINCRONA.js
// Si ya activaron usuarios (carpeta 5_USUARIOS), indiquen un usuario con permisos
// de escritura en la variable USUARIO (por ejemplo 'dba_mongo'); pedirá la contraseña.
// La demostración tarda poco más de 1 minuto (espera el retraso del nodo 3).
// =====================================================================

const USUARIO = 'dba_mongo';              // en Docker se autentica con la variable de entorno P (la pone 04_demo_replicacion.sh)
const CLAVE = process.env.P;

function conectar(puerto) {               // conexión directa a un nodo concreto
  const c = new Mongo('mongodb://mongo' + (puerto - 27016) + ':27017/?directConnection=true');
  if (USUARIO) c.getDB('admin').auth(USUARIO, CLAVE);
  c.setReadPref('secondaryPreferred');    // permite leer en un secundario
  return c.getDB('mercado_nosql');
}
const bd = db.getSiblingDB('mercado_nosql');
if (USUARIO) db.getSiblingDB('admin').auth(USUARIO, CLAVE);

const estado = () => {
  const st = rs.status(), p = st.members.find(m => m.stateStr === 'PRIMARY');
  console.table(st.members.map(m => ({
    nodo: m.name, estado: m.stateStr,
    retraso_seg: Math.round((p.optimeDate - m.optimeDate) / 1000) })));
};

print('\n--- 1) Estado del replica set (retraso_seg = cuánto va detrás del primario) ---');
estado();

print('\n--- 2) Escribir una incidencia de prueba en el PRIMARIO (w:1, sin esperar a los secundarios) ---');
const doc = { _id: 'INC-999999', tipo: 'ENTREGA_NO_REALIZADA', severidad: 'BAJA',
  origen: { sistema: 'oracle', tabla: 'entrega', id: 0 }, fecha: new Date(),
  descripcion: 'Documento de demostración de replicación', estado: 'ABIERTA',
  historial: [{ fecha: new Date(), estado: 'REGISTRADA', nota: 'Demo' }] };
bd.incidencias.deleteOne({ _id: 'INC-999999' });
const t0 = Date.now();
bd.incidencias.insertOne(doc, { writeConcern: { w: 1 } });
print('El primario confirmó la escritura en ' + (Date.now() - t0) + ' ms');

const cuenta = (puerto) => conectar(puerto).incidencias.countDocuments({ _id: 'INC-999999' });
print('\n--- 3) ¿Dónde está el documento? (1 = ya está, 0 = todavía no) ---');
sleep(2000);
console.table([
  { nodo: 'nodo 1 (27017) primario', encontrado: cuenta(27017) },
  { nodo: 'nodo 2 (27018) secundario', encontrado: cuenta(27018) },
  { nodo: 'nodo 3 (27019) retraso 60 s', encontrado: cuenta(27019) } ]);

print('--- 4) Esperando 65 s a que el nodo 3 aplique el cambio ... ---');
sleep(65000);
console.table([{ nodo: 'nodo 3 (27019) tras 65 s', encontrado: cuenta(27019) }]);

print('\n--- 5) Costo de esperar a los secundarios: 50 inserciones con w:1 vs w:"majority" ---');
function medir(wc, marca) {
  const t = Date.now();
  for (let i = 0; i < 50; i++) bd.incidencias.insertOne({ _id: 'INC-9' + marca + String(i).padStart(4, '0'),   // INC-91xxxx / INC-92xxxx: no chocan con los reales (INC-00xxxx)
    tipo: 'PAGO_ANULADO', severidad: 'BAJA', origen: { sistema: 'oracle', tabla: 'pago', id: 0 },
    fecha: new Date(), estado: 'ABIERTA', historial: [{ fecha: new Date(), estado: 'REGISTRADA' }] }, { writeConcern: wc });
  return Date.now() - t;
}
const msW1 = medir({ w: 1 }, 1), msMaj = medir({ w: 'majority' }, 2);
console.table([{ escritura: 'w:1 (asíncrona)', ms_50_inserciones: msW1 },
               { escritura: 'w:majority (espera a un secundario)', ms_50_inserciones: msMaj }]);

// Limpieza de los documentos de prueba
bd.incidencias.deleteMany({ _id: /^INC-9/ });   // elimina INC-999999, INC-91xxxx e INC-92xxxx
print('\nDocumentos de prueba eliminados.');

print('\n--- 6) Información del oplog (registro que leen los secundarios) ---');
rs.printReplicationInfo();
print('\nPara probar la conmutación por falla (failover), ejecuten en el primario:');
print('    rs.stepDown()    // el nodo 2 pasa a ser PRIMARIO; luego vuelve a mostrar estado()');
