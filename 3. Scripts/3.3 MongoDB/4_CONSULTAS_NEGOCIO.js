// =====================================================================
// 4_CONSULTAS_NEGOCIO.js  -  Mercado Directo (MongoDB)
// Ocho consultas que responden preguntas de negocio sobre las colecciones
// seguimiento_ruta, calificaciones, incidencias y perfil_agricultor.
//
// Ejecutar con mongosh (después de crear y cargar las colecciones):
//     mongosh --file 4_CONSULTAS_NEGOCIO.js
// =====================================================================

const bd = db.getSiblingDB('mercado_nosql');
const titulo = (t) => print('\n=== ' + t + ' ===');

// ---------------------------------------------------------------------
// Q1. ¿Qué agricultores ofrecen la mejor calidad percibida?
//     (top 10 con al menos 15 calificaciones, para que el promedio sea confiable)
// ---------------------------------------------------------------------
titulo('Q1. Mejores agricultores (mínimo 15 calificaciones)');
console.table(bd.perfil_agricultor.aggregate([
  { $match: { total_calificaciones: { $gte: 15 } } },
  { $sort: { puntuacion_promedio: -1, total_calificaciones: -1 } },
  { $limit: 10 },
  { $project: { _id: 1, nombre: 1, total_calificaciones: 1, puntuacion_promedio: 1,
                frescura: '$promedio_aspectos.frescura', puntualidad: '$promedio_aspectos.puntualidad' } }
]).toArray());

// ---------------------------------------------------------------------
// Q2. ¿Qué categorías de producto son mejor y peor valoradas por los clientes?
// ---------------------------------------------------------------------
titulo('Q2. Valoración por categoría de producto');
console.table(bd.calificaciones.aggregate([
  { $group: { _id: '$producto.categoria', calificaciones: { $sum: 1 },
              promedio: { $avg: '$puntuacion' }, frescura: { $avg: '$aspectos.frescura' },
              empaque: { $avg: '$aspectos.empaque' } } },
  { $project: { categoria: '$_id', _id: 0, calificaciones: 1,
                promedio: { $round: ['$promedio', 2] }, frescura: { $round: ['$frescura', 2] },
                empaque: { $round: ['$empaque', 2] } } },
  { $sort: { promedio: -1 } }
]).toArray());

// ---------------------------------------------------------------------
// Q3. ¿Qué tipos de incidencia son más frecuentes y qué tan graves son?
// ---------------------------------------------------------------------
titulo('Q3. Incidencias por tipo y severidad');
console.table(bd.incidencias.aggregate([
  { $group: { _id: { tipo: '$tipo', severidad: '$severidad' }, total: { $sum: 1 } } },
  { $project: { _id: 0, tipo: '$_id.tipo', severidad: '$_id.severidad', total: 1 } },
  { $sort: { total: -1 } }
]).toArray());

// ---------------------------------------------------------------------
// Q4. ¿Qué centros de acopio concentran más recepciones observadas o rechazadas?
//     (los nombres de los centros se toman de seguimiento_ruta)
// ---------------------------------------------------------------------
titulo('Q4. Centros de acopio con más incidencias de recepción');
const nombres = {};
bd.seguimiento_ruta.aggregate([
  { $group: { _id: '$centro_acopio.centro_acopio_id', nombre: { $first: '$centro_acopio.nombre' } } }
]).forEach(c => { nombres[c._id] = c.nombre; });
console.table(bd.incidencias.aggregate([
  { $match: { tipo: { $in: ['RECEPCION_OBSERVADA', 'RECEPCION_RECHAZADA'] } } },
  { $group: { _id: '$referencias.centro_acopio_id', total: { $sum: 1 },
              rechazadas: { $sum: { $cond: [{ $eq: ['$tipo', 'RECEPCION_RECHAZADA'] }, 1, 0] } } } },
  { $sort: { total: -1 } },
  { $limit: 5 }
]).toArray().map(r => ({ centro: nombres[r._id] || r._id, total: r.total, rechazadas: r.rechazadas })));

// ---------------------------------------------------------------------
// Q5. ¿Qué transportistas tienen la mayor tasa de entregas fallidas o rechazadas?
//     (solo quienes atendieron al menos 150 paradas)
// ---------------------------------------------------------------------
titulo('Q5. Transportistas con más entregas no exitosas');
console.table(bd.seguimiento_ruta.aggregate([
  { $unwind: '$eventos' },
  { $match: { 'eventos.tipo': { $ne: 'SALIDA' } } },
  { $group: { _id: { id: '$transportista.transportista_id', nombre: '$transportista.nombre' },
              paradas: { $sum: 1 },
              no_exitosas: { $sum: { $cond: [{ $in: ['$eventos.tipo', ['ENTREGA_FALLIDA', 'ENTREGA_RECHAZADA']] }, 1, 0] } } } },
  { $match: { paradas: { $gte: 150 } } },
  { $project: { _id: 0, transportista: '$_id.nombre', paradas: 1, no_exitosas: 1,
                tasa_pct: { $round: [{ $multiply: [{ $divide: ['$no_exitosas', '$paradas'] }, 100] }, 2] } } },
  { $sort: { tasa_pct: -1 } },
  { $limit: 10 }
]).toArray());

// ---------------------------------------------------------------------
// Q6. ¿Cómo evoluciona mes a mes la satisfacción de los clientes?
// ---------------------------------------------------------------------
titulo('Q6. Tendencia mensual de la calificación');
console.table(bd.calificaciones.aggregate([
  { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$fecha' } },
              calificaciones: { $sum: 1 }, promedio: { $avg: '$puntuacion' },
              puntualidad: { $avg: '$aspectos.puntualidad' } } },
  { $project: { _id: 0, mes: '$_id', calificaciones: 1,
                promedio: { $round: ['$promedio', 2] }, puntualidad: { $round: ['$puntualidad', 2] } } },
  { $sort: { mes: 1 } }
]).toArray());

// ---------------------------------------------------------------------
// Q7. ¿A qué clientes conviene contactar por una mala experiencia?
//     (clientes con 2 o más calificaciones de 1 o 2 estrellas)
// ---------------------------------------------------------------------
titulo('Q7. Clientes con experiencias negativas repetidas');
console.table(bd.calificaciones.aggregate([
  { $match: { puntuacion: { $lte: 2 } } },
  { $group: { _id: { id: '$cliente.cliente_id', nombre: '$cliente.nombre' },
              malas_experiencias: { $sum: 1 }, ultima: { $max: '$fecha' } } },
  { $match: { malas_experiencias: { $gte: 2 } } },
  { $project: { _id: 0, cliente_id: '$_id.id', cliente: '$_id.nombre', malas_experiencias: 1,
                ultima: { $dateToString: { format: '%Y-%m-%d', date: '$ultima' } } } },
  { $sort: { malas_experiencias: -1, ultima: -1 } },
  { $limit: 10 }
]).toArray());

// ---------------------------------------------------------------------
// Q8. ¿Cuáles son las incidencias graves que siguen sin resolverse?
//     (severidad ALTA y estado distinto de RESUELTA)
// ---------------------------------------------------------------------
titulo('Q8. Incidencias de severidad ALTA sin resolver');
console.table(bd.incidencias.find(
  { severidad: 'ALTA', estado: { $ne: 'RESUELTA' } },
  { tipo: 1, estado: 1, descripcion: 1, 'referencias.pedido_id': 1 }
).sort({ fecha: -1 }).limit(8).toArray().map(d => ({
  id: d._id, tipo: d.tipo, estado: d.estado,
  pedido_id: d.referencias ? d.referencias.pedido_id : null, descripcion: d.descripcion })));
