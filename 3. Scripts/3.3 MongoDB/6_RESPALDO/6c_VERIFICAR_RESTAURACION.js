// =====================================================================
// 6c_VERIFICAR_RESTAURACION.js  -  Mercado Directo (MongoDB)
// Compara la base original (mercado_nosql) con la restaurada
// (mercado_restaurada): cantidad de documentos, índices, validador y una
// muestra de documentos (se comparan completos).
// Lo invoca 6b_RESTAURAR_Y_VERIFICAR.ps1, o se puede ejecutar a mano:
//     mongosh "mongodb://localhost:27017/?replicaSet=rs_mercado" -u dba_mongo --authenticationDatabase admin --file 6c_VERIFICAR_RESTAURACION.js
// =====================================================================

const origen = db.getSiblingDB('mercado_nosql');
const copia = db.getSiblingDB('mercado_restaurada');
const colecciones = ['seguimiento_ruta', 'calificaciones', 'incidencias', 'perfil_agricultor'];

const nombresIdx = (bd, c) => bd.getCollection(c).getIndexes().map(i => i.name).sort().join(',');
const tieneValidador = (bd, c) => {
  const info = bd.getCollectionInfos({ name: c })[0];
  return !!(info && info.options && info.options.validator);
};
// Muestra: primeros 200 y últimos 200 documentos (por _id), comparados completos
const muestra = (bd, c) => EJSON.stringify(
  bd.getCollection(c).find().sort({ _id: 1 }).limit(200).toArray()
    .concat(bd.getCollection(c).find().sort({ _id: -1 }).limit(200).toArray()));

const filas = colecciones.map(c => {
  const a = origen[c].countDocuments(), b = copia[c].countDocuments();
  const idx = nombresIdx(origen, c) === nombresIdx(copia, c);
  const val = tieneValidador(origen, c) === tieneValidador(copia, c);
  const mue = muestra(origen, c) === muestra(copia, c);
  return { coleccion: c, original: a, restaurada: b, mismos_documentos: a === b ? 'OK' : 'FALLA',
           indices: idx ? 'OK' : 'FALLA', validador: val ? 'OK' : 'FALLA', muestra_identica: mue ? 'OK' : 'FALLA' };
});
console.table(filas);
const todoOk = filas.every(f => [f.mismos_documentos, f.indices, f.validador, f.muestra_identica].every(x => x === 'OK'));
print(todoOk ? 'RESULTADO: la restauración es idéntica al original.' : 'RESULTADO: HAY DIFERENCIAS, revisar.');
