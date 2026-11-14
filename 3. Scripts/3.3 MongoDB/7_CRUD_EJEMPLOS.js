// =====================================================================
// 7_CRUD_EJEMPLOS.js  -  Mercado Directo (MongoDB)
// Ejemplos de CREATE / READ / UPDATE / DELETE en 3 niveles (básico, intermedio,
// avanzado) para las 4 colecciones. Es el mismo código que muestra la guía.
//
// Se ejecuta en mongosh, de preferencia sección por sección (copiar y pegar),
// como administrador (el rol de la aplicación no puede borrar).
//     use mercado_nosql
//
// IMPORTANTE: todos los UPDATE y DELETE actúan solo sobre datos de PRÁCTICA:
// los _id >= 900000 (o 'INC-900000' en incidencias) que crean los CREATE de este
// archivo. Los datos reales (ids menores) no se tocan. El último DELETE limpia todo.
// =====================================================================
use('mercado_nosql')


// ==================================================================
// COLECCIÓN seguimiento_ruta
// ==================================================================

// --- CREATE / Básico: Registrar una ruta programada
db.seguimiento_ruta.insertOne({
  _id: 900001, codigo_ruta: 'RT-2026-900001', estado: 'PROGRAMADA',
  centro_acopio: { centro_acopio_id: 12, codigo: 'CA-012',
    nombre: 'Centro de Acopio Chiclayo', distrito: 'Chiclayo' },
  transportista: { transportista_id: 133, nombre: 'Alfredo Puma Ochoa', licencia: 'Q40114820' },
  vehiculo: { vehiculo_id: 111, placa: 'XPG-013', tipo: 'MOTOCARGUERO', capacidad_kg: 250, refrigerado: true },
  salida: new Date(), distancia_km: 18.5, total_paradas: 2, paradas_entregadas: 0,
  eventos: [ { orden: 0, tipo: 'SALIDA', fecha: new Date(), detalle: 'Salida del centro de acopio' } ]
})

// --- CREATE / Intermedio: Varias rutas con insertMany
const base = { estado: 'PROGRAMADA', total_paradas: 1, paradas_entregadas: 0, distancia_km: 9.2,
  centro_acopio: { centro_acopio_id: 12, codigo: 'CA-012',
    nombre: 'Centro de Acopio Chiclayo', distrito: 'Chiclayo' },
  transportista: { transportista_id: 133, nombre: 'Alfredo Puma Ochoa' },
  vehiculo: { vehiculo_id: 111, placa: 'XPG-013' }, salida: new Date(),
  eventos: [ { orden: 0, tipo: 'SALIDA', fecha: new Date() } ] }
db.seguimiento_ruta.insertMany([
  { ...base, _id: 900002, codigo_ruta: 'RT-2026-900002' },
  { ...base, _id: 900003, codigo_ruta: 'RT-2026-900003' }
])

// --- CREATE / Avanzado: bulkWrite: una ruta y su incidencia en una sola operación
db.seguimiento_ruta.bulkWrite([
  { insertOne: { document: {
      _id: 900004, codigo_ruta: 'RT-2026-900004', estado: 'CANCELADA',
      centro_acopio: { centro_acopio_id: 12, nombre: 'Centro de Acopio Chiclayo' },
      transportista: { transportista_id: 133, nombre: 'Alfredo Puma Ochoa' },
      vehiculo: { vehiculo_id: 111, placa: 'XPG-013' },
      salida: new Date(), distancia_km: 0,
      eventos: [ { orden: 0, tipo: 'SALIDA', fecha: new Date(), detalle: 'Ruta cancelada' } ] } } }
])
db.incidencias.insertOne({
  _id: 'INC-900010', tipo: 'ENTREGA_NO_REALIZADA', severidad: 'MEDIA',
  origen: { sistema: 'oracle', tabla: 'ruta', id: 900004 }, referencias: { ruta_id: 900004 },
  fecha: new Date(), estado: 'ABIERTA',
  historial: [ { fecha: new Date(), estado: 'REGISTRADA', nota: 'Ruta cancelada por lluvia' } ] })

// --- READ / Básico: Buscar una ruta por su código (Op. 1)
db.seguimiento_ruta.findOne({ codigo_ruta: 'RT-2026-000001' })

// --- READ / Intermedio: Últimas rutas completadas con proyección (Op. 2)
db.seguimiento_ruta.find(
  { estado: 'COMPLETADA' },
  { codigo_ruta: 1, 'transportista.nombre': 1, salida: 1, distancia_km: 1, _id: 0 }
).sort({ salida: -1 }).limit(5)

// --- READ / Avanzado: ¿Qué ruta atendió el pedido 28407? ($elemMatch en el arreglo de eventos) (Op. 5)
db.seguimiento_ruta.find(
  { 'eventos.pedido_id': 28407 },
  { codigo_ruta: 1, estado: 1, eventos: { $elemMatch: { pedido_id: 28407 } } }
)

// --- UPDATE / Básico: Cambiar el estado de una ruta
db.seguimiento_ruta.updateOne({ _id: 900001 }, { $set: { estado: 'EN CURSO' } })

// --- UPDATE / Intermedio: Registrar una entrega: agregar evento y sumar parada (Op. 3)
db.seguimiento_ruta.updateOne(
  { _id: 900001 },
  { $push: { eventos: { orden: 1, tipo: 'ENTREGA_REALIZADA', fecha: new Date(),
                        pedido_id: 28407, entrega_id: 900001, detalle: 'Recibido en puerta' } },
    $inc: { paradas_entregadas: 1 } }
)

// --- UPDATE / Avanzado: Pipeline: completar las rutas de prueba con todas sus paradas entregadas
db.seguimiento_ruta.updateMany(
  { _id: { $gte: 900000 }, estado: 'EN CURSO' },
  [ { $set: { estado: { $cond: [ { $gte: ['$paradas_entregadas', '$total_paradas'] },
                                 'COMPLETADA', '$estado' ] } } } ]
)

// --- DELETE / Básico: Eliminar una ruta de prueba
db.seguimiento_ruta.deleteOne({ _id: 900001 })

// --- DELETE / Intermedio: Eliminar un rango de rutas de prueba
db.seguimiento_ruta.deleteMany({ _id: { $gte: 900000, $lt: 900010 }, estado: 'PROGRAMADA' })

// --- DELETE / Avanzado: Eliminar rutas de prueba que no tienen ninguna entrega
db.seguimiento_ruta.deleteMany({
  _id: { $gte: 900000 },
  eventos: { $not: { $elemMatch: { tipo: { $ne: 'SALIDA' } } } }
})

// ==================================================================
// COLECCIÓN calificaciones
// ==================================================================

// --- CREATE / Básico: Registrar la calificación de un pedido
db.calificaciones.insertOne({
  _id: 900001, pedido_id: 900001, fecha: new Date(),
  cliente: { cliente_id: 6930, nombre: 'Pollería Doña Carmen E.I.R.L.' },
  agricultor: { agricultor_id: 157, nombre: 'Ciro Tupayachi Camones' },
  producto: { producto_id: 18, nombre: 'Choclo', categoria: 'Granos' },
  puntuacion: 5, aspectos: { frescura: 5, puntualidad: 4, empaque: 5 },
  comentario: 'Excelente calidad', etiquetas: ['fresco'], simulado: true
})

// --- CREATE / Intermedio: Varias calificaciones con insertMany
const cal = { fecha: new Date(), simulado: true,
  cliente: { cliente_id: 6930, nombre: 'Pollería Doña Carmen E.I.R.L.' },
  agricultor: { agricultor_id: 157, nombre: 'Ciro Tupayachi Camones' },
  producto: { producto_id: 18, nombre: 'Choclo', categoria: 'Granos' },
}
db.calificaciones.insertMany([
  { ...cal, _id: 900002, pedido_id: 900002, puntuacion: 2,
    aspectos: { frescura: 3, puntualidad: 1, empaque: 2 }, etiquetas: ['demora'] },
  { ...cal, _id: 900003, pedido_id: 900003, puntuacion: 4,
    aspectos: { frescura: 4, puntualidad: 4, empaque: 4 }, etiquetas: [] }
])

// --- CREATE / Avanzado: Transacción: guardar la calificación y actualizar el perfil del agricultor
const sesion = db.getMongo().startSession()
const sdb = sesion.getDatabase('mercado_nosql')
sesion.startTransaction()
try {
  sdb.calificaciones.insertOne({
    _id: 900004, pedido_id: 900004, fecha: new Date(),
    cliente: { cliente_id: 6930, nombre: 'Pollería Doña Carmen E.I.R.L.' },
  agricultor: { agricultor_id: 157, nombre: 'Ciro Tupayachi Camones' },
  producto: { producto_id: 18, nombre: 'Choclo', categoria: 'Granos' },
    puntuacion: 4, aspectos: { frescura: 4, puntualidad: 4, empaque: 5 }, simulado: true })
  sdb.perfil_agricultor.updateOne({ _id: 157 },
    { $inc: { total_calificaciones: 1 }, $currentDate: { ultima_calificacion: true } })
  sesion.commitTransaction(); print('Calificación registrada y perfil actualizado')
} catch (e) { sesion.abortTransaction(); print('Error: ' + e.message) }
finally { sesion.endSession() }

// --- READ / Básico: Últimas calificaciones de un agricultor (Op. 7)
db.calificaciones.find({ 'agricultor.agricultor_id': 157 }).sort({ fecha: -1 }).limit(5)

// --- READ / Intermedio: Calificaciones bajas por demora, con proyección
db.calificaciones.find(
  { puntuacion: { $lte: 2 }, etiquetas: 'demora' },
  { pedido_id: 1, puntuacion: 1, 'aspectos.puntualidad': 1, comentario: 1, _id: 0 }
).limit(5)

// --- READ / Avanzado: Promedio por producto de un agricultor ($group)
db.calificaciones.aggregate([
  { $match: { 'agricultor.agricultor_id': 157 } },
  { $group: { _id: '$producto.nombre', calificaciones: { $sum: 1 }, promedio: { $avg: '$puntuacion' } } },
  { $project: { _id: 0, producto: '$_id', calificaciones: 1, promedio: { $round: ['$promedio', 2] } } },
  { $sort: { promedio: -1 } }
])

// --- UPDATE / Básico: Corregir un comentario
db.calificaciones.updateOne({ _id: 900001 }, { $set: { comentario: 'Comentario revisado por soporte' } })

// --- UPDATE / Intermedio: Agregar una etiqueta sin duplicados ($addToSet)
db.calificaciones.updateOne({ _id: 900001 }, { $addToSet: { etiquetas: 'recomendado' } })

// --- UPDATE / Avanzado: Pipeline: recalcular la puntuación como promedio de los tres aspectos
db.calificaciones.updateMany(
  { _id: { $gte: 900000 } },
  [ { $set: { puntuacion: { $toInt: { $round: [
      { $avg: ['$aspectos.frescura', '$aspectos.puntualidad', '$aspectos.empaque'] }, 0 ] } } } } ]
)

// --- DELETE / Básico: Eliminar una calificación de prueba
db.calificaciones.deleteOne({ _id: 900001 })

// --- DELETE / Intermedio: Eliminar las calificaciones de prueba menores a 3
db.calificaciones.deleteMany({ _id: { $gte: 900000 }, puntuacion: { $lt: 3 } })

// --- DELETE / Avanzado: Eliminar las de prueba con comentario largo ($expr)
db.calificaciones.deleteMany({
  _id: { $gte: 900000 },
  $expr: { $gt: [ { $strLenCP: { $ifNull: ['$comentario', ''] } }, 20 ] }
})

// ==================================================================
// COLECCIÓN incidencias
// ==================================================================

// --- CREATE / Básico: Registrar una incidencia
db.incidencias.insertOne({
  _id: 'INC-900001', tipo: 'RECEPCION_OBSERVADA', severidad: 'BAJA',
  origen: { sistema: 'oracle', tabla: 'recepcion_acopio', id: 1 },
  fecha: new Date(), descripcion: 'Producto con golpes leves', estado: 'ABIERTA',
  historial: [ { fecha: new Date(), estado: 'REGISTRADA', nota: 'Detectada en recepción' } ]
})

// --- CREATE / Intermedio: Varias incidencias con insertMany
const orig = { sistema: 'oracle', tabla: 'pago', id: 1 }, hist = [ { fecha: new Date(), estado: 'REGISTRADA' } ]
db.incidencias.insertMany([
  { _id: 'INC-900002', tipo: 'PAGO_RECHAZADO', severidad: 'ALTA', origen: orig,
    referencias: { pedido_id: 28407, monto: 120.5 }, fecha: new Date(), estado: 'ABIERTA', historial: hist },
  { _id: 'INC-900003', tipo: 'PAGO_REEMBOLSADO', severidad: 'MEDIA', origen: orig,
    referencias: { pedido_id: 28481, monto: 80 }, fecha: new Date(), estado: 'ABIERTA', historial: hist }
])

// --- CREATE / Avanzado: Incidencia con referencias y un historial de varios pasos
db.incidencias.insertOne({
  _id: 'INC-900004', tipo: 'ENTREGA_RECHAZADA', severidad: 'ALTA',
  origen: { sistema: 'oracle', tabla: 'entrega', id: 2 },
  referencias: { pedido_id: 28481, ruta_id: 1, centro_acopio_id: 12 },
  fecha: new Date(), descripcion: 'El cliente rechazó la entrega', estado: 'EN_REVISION',
  historial: [
    { fecha: new Date(Date.now() - 3600000), estado: 'REGISTRADA', nota: 'Reportada por el transportista' },
    { fecha: new Date(), estado: 'EN_REVISION', nota: 'Atención al cliente la está revisando' }
  ]
})

// --- READ / Básico: Incidencias abiertas
db.incidencias.find({ estado: 'ABIERTA' }).limit(5)

// --- READ / Intermedio: Incidencias graves sin resolver, las más recientes primero (Op. 12)
db.incidencias.find(
  { severidad: 'ALTA', estado: { $ne: 'RESUELTA' } },
  { tipo: 1, estado: 1, 'referencias.pedido_id': 1, fecha: 1 }
).sort({ fecha: -1 }).limit(5)

// --- READ / Avanzado: $lookup: entregas no realizadas con el transportista de la ruta
db.incidencias.aggregate([
  { $match: { tipo: 'ENTREGA_NO_REALIZADA', 'referencias.ruta_id': { $exists: true } } },
  { $limit: 5 },
  { $lookup: { from: 'seguimiento_ruta', localField: 'referencias.ruta_id',
               foreignField: '_id', as: 'ruta' } },
  { $unwind: '$ruta' },
  { $project: { _id: 1, estado: 1, codigo_ruta: '$ruta.codigo_ruta',
                transportista: '$ruta.transportista.nombre' } }
])

// --- UPDATE / Básico: Pasar una incidencia a revisión
db.incidencias.updateOne({ _id: 'INC-900001' }, { $set: { estado: 'EN_REVISION' } })

// --- UPDATE / Intermedio: Resolver una incidencia y registrar el paso en el historial (Op. 11)
db.incidencias.updateOne(
  { _id: 'INC-900001' },
  { $set: { estado: 'RESUELTA' },
    $push: { historial: { fecha: new Date(), estado: 'RESUELTA', nota: 'Se repuso el producto' } } }
)

// --- UPDATE / Avanzado: Pipeline: subir a ALTA las incidencias de prueba abiertas hace más de 30 días
db.incidencias.updateMany(
  { _id: { $gte: 'INC-900000' }, estado: 'ABIERTA' },
  [ { $set: { severidad: { $cond: [
      { $lt: ['$fecha', new Date(Date.now() - 30 * 24 * 3600 * 1000)] }, 'ALTA', '$severidad' ] } } } ]
)

// --- DELETE / Básico: Eliminar una incidencia de prueba
db.incidencias.deleteOne({ _id: 'INC-900001' })

// --- DELETE / Intermedio: Eliminar las incidencias de prueba ya resueltas
db.incidencias.deleteMany({ _id: { $gte: 'INC-900000' }, estado: 'RESUELTA' })

// --- DELETE / Avanzado: Eliminar las de prueba cuyo historial tiene un solo paso ($expr)
db.incidencias.deleteMany({
  _id: { $gte: 'INC-900000' },
  $expr: { $lte: [ { $size: '$historial' }, 1 ] }
})

// ==================================================================
// COLECCIÓN perfil_agricultor
// ==================================================================

// --- CREATE / Básico: Crear el perfil de un agricultor de prueba
db.perfil_agricultor.insertOne({
  _id: 900001, nombre: 'Agricultor de prueba', total_calificaciones: 1, puntuacion_promedio: 4,
  promedio_aspectos: { frescura: 4, puntualidad: 4, empaque: 4 },
  productos: [ { producto_id: 18, nombre: 'Choclo', calificaciones: 1, promedio: 4 } ],
  ultima_calificacion: new Date(), simulado: true
})

// --- CREATE / Intermedio: Varios perfiles con insertMany
db.perfil_agricultor.insertMany([
  { _id: 900002, nombre: 'Agricultor de prueba 2', total_calificaciones: 10,
    puntuacion_promedio: 4.6, simulado: true },
  { _id: 900003, nombre: 'Agricultor de prueba 3', total_calificaciones: 3,
    puntuacion_promedio: 2.7, simulado: true }
])

// --- CREATE / Avanzado: $merge: calcular un perfil desde calificaciones y guardarlo en una colección de práctica
db.calificaciones.aggregate([
  { $match: { 'agricultor.agricultor_id': 157 } },
  { $group: { _id: '$agricultor.agricultor_id', nombre: { $first: '$agricultor.nombre' },
              total_calificaciones: { $sum: 1 }, puntuacion_promedio: { $avg: '$puntuacion' } } },
  { $merge: { into: 'perfil_agricultor_demo', whenMatched: 'replace', whenNotMatched: 'insert' } }
])
db.perfil_agricultor_demo.find()

// --- READ / Básico: Perfil de un agricultor
db.perfil_agricultor.findOne({ _id: 157 })

// --- READ / Intermedio: Ranking de agricultores con al menos 15 calificaciones (Op. 15)
db.perfil_agricultor.find(
  { total_calificaciones: { $gte: 15 } },
  { nombre: 1, total_calificaciones: 1, puntuacion_promedio: 1 }
).sort({ puntuacion_promedio: -1 }).limit(5)

// --- READ / Avanzado: Mejores productos entre todos los agricultores ($unwind)
db.perfil_agricultor.aggregate([
  { $unwind: '$productos' },
  { $match: { 'productos.calificaciones': { $gte: 5 } } },
  { $sort: { 'productos.promedio': -1 } },
  { $limit: 5 },
  { $project: { _id: 0, agricultor: '$nombre', producto: '$productos.nombre',
                promedio: '$productos.promedio', calificaciones: '$productos.calificaciones' } }
])

// --- UPDATE / Básico: Cambiar el promedio de un perfil
db.perfil_agricultor.updateOne({ _id: 900001 }, { $set: { puntuacion_promedio: 4.5 } })

// --- UPDATE / Intermedio: Sumar una calificación y actualizar la fecha ($inc, $currentDate)
db.perfil_agricultor.updateOne(
  { _id: 900001 },
  { $inc: { total_calificaciones: 1 }, $currentDate: { ultima_calificacion: true } }
)

// --- UPDATE / Avanzado: Modificar un elemento del arreglo productos con arrayFilters
db.perfil_agricultor.updateOne(
  { _id: 900001 },
  { $set: { 'productos.$[p].promedio': 4.8 }, $inc: { 'productos.$[p].calificaciones': 1 } },
  { arrayFilters: [ { 'p.producto_id': 18 } ] }
)

// --- DELETE / Básico: Eliminar un perfil de prueba
db.perfil_agricultor.deleteOne({ _id: 900001 })

// --- DELETE / Intermedio: Eliminar los perfiles de prueba con pocas calificaciones
db.perfil_agricultor.deleteMany({ _id: { $gte: 900000 }, total_calificaciones: { $lt: 5 } })

// --- DELETE / Avanzado: Eliminar la colección de práctica y todos los datos de prueba restantes
db.perfil_agricultor_demo.drop()
db.perfil_agricultor.deleteMany({ _id: { $gte: 900000 } })
db.calificaciones.deleteMany({ _id: { $gte: 900000 } })
db.seguimiento_ruta.deleteMany({ _id: { $gte: 900000 } })
db.incidencias.deleteMany({ _id: { $gte: 'INC-900000' } })
