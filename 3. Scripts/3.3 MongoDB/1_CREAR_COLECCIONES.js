// =====================================================================
// 1_CREAR_COLECCIONES.js  -  Mercado Directo (MongoDB)
// Crea la base "mercado_nosql", las 4 colecciones con su validador
// ($jsonSchema) y sus índices.
//
// Ejecutar con mongosh:
//     mongosh --file 1_CREAR_COLECCIONES.js
// (si el servidor tiene usuarios activados, agregar --username/--password)
//
// Se puede ejecutar varias veces: borra y vuelve a crear las colecciones.
// =====================================================================

const bd = db.getSiblingDB('mercado_nosql');

['seguimiento_ruta', 'calificaciones', 'incidencias', 'perfil_agricultor']
  .forEach(c => bd.getCollection(c).drop());

// Los ids vienen de Oracle/PostgreSQL: pueden ser int o long según el valor.
const entero = { bsonType: ['int', 'long'] };

// ---------------------------------------------------------------------
// 1) seguimiento_ruta: una ruta de reparto (Oracle: ruta_reparto) con
//    sus paradas/eventos incrustados. _id = ruta_id de Oracle.
// ---------------------------------------------------------------------
bd.createCollection('seguimiento_ruta', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'codigo_ruta', 'estado', 'centro_acopio', 'transportista',
               'vehiculo', 'salida', 'distancia_km', 'eventos'],
    properties: {
      _id: entero,
      codigo_ruta: { bsonType: 'string', pattern: '^RT-[0-9]{4}-[0-9]{6}$' },
      estado: { enum: ['PROGRAMADA', 'EN CURSO', 'COMPLETADA', 'CANCELADA'] },
      centro_acopio: { bsonType: 'object', required: ['centro_acopio_id', 'nombre'],
        properties: { centro_acopio_id: entero, codigo: { bsonType: 'string' },
                      nombre: { bsonType: 'string' }, distrito: { bsonType: 'string' } } },
      transportista: { bsonType: 'object', required: ['transportista_id', 'nombre'],
        properties: { transportista_id: entero, nombre: { bsonType: 'string' },
                      licencia: { bsonType: 'string' } } },
      vehiculo: { bsonType: 'object', required: ['vehiculo_id', 'placa'],
        properties: { vehiculo_id: entero, placa: { bsonType: 'string' },
                      tipo: { bsonType: 'string' }, capacidad_kg: { bsonType: 'number', minimum: 0 },
                      refrigerado: { bsonType: 'bool' } } },
      salida: { bsonType: 'date' },
      retorno_estimado: { bsonType: 'date' },
      distancia_km: { bsonType: 'number', minimum: 0 },
      total_paradas: { bsonType: 'int', minimum: 0 },
      paradas_entregadas: { bsonType: 'int', minimum: 0 },
      eventos: { bsonType: 'array', minItems: 1,
        items: { bsonType: 'object', required: ['orden', 'tipo', 'fecha'],
          properties: {
            orden: { bsonType: 'int', minimum: 0 },
            tipo: { enum: ['SALIDA', 'ENTREGA_REALIZADA', 'ENTREGA_FALLIDA',
                           'ENTREGA_RECHAZADA', 'ENTREGA_PENDIENTE'] },
            fecha: { bsonType: 'date' },
            pedido_id: entero, entrega_id: entero,
            detalle: { bsonType: ['string', 'null'] } } } }
    } } },
  validationLevel: 'strict', validationAction: 'error'
});
bd.seguimiento_ruta.createIndex({ codigo_ruta: 1 }, { unique: true, name: 'uq_codigo_ruta' });
bd.seguimiento_ruta.createIndex({ estado: 1, salida: -1 }, { name: 'ix_estado_salida' });
bd.seguimiento_ruta.createIndex({ 'transportista.transportista_id': 1 }, { name: 'ix_transportista' });
bd.seguimiento_ruta.createIndex({ 'centro_acopio.centro_acopio_id': 1 }, { name: 'ix_centro' });
bd.seguimiento_ruta.createIndex({ 'eventos.pedido_id': 1 }, { name: 'ix_evento_pedido' });   // índice multiclave

// ---------------------------------------------------------------------
// 2) calificaciones: opinión del cliente tras recibir un pedido.
//    _id = pedido_id de PostgreSQL (una calificación por pedido).
// ---------------------------------------------------------------------
const nota = { bsonType: 'int', minimum: 1, maximum: 5 };
bd.createCollection('calificaciones', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'pedido_id', 'fecha', 'cliente', 'agricultor', 'producto',
               'puntuacion', 'aspectos'],
    properties: {
      _id: entero, pedido_id: entero, fecha: { bsonType: 'date' },
      cliente: { bsonType: 'object', required: ['cliente_id'],
        properties: { cliente_id: entero, nombre: { bsonType: 'string' } } },
      agricultor: { bsonType: 'object', required: ['agricultor_id'],
        properties: { agricultor_id: entero, nombre: { bsonType: 'string' } } },
      producto: { bsonType: 'object', required: ['producto_id'],
        properties: { producto_id: entero, nombre: { bsonType: 'string' },
                      categoria: { bsonType: 'string' } } },
      ruta_id: entero,
      puntuacion: nota,
      aspectos: { bsonType: 'object', required: ['frescura', 'puntualidad', 'empaque'],
        properties: { frescura: nota, puntualidad: nota, empaque: nota } },
      comentario: { bsonType: 'string', maxLength: 300 },
      etiquetas: { bsonType: 'array', items: { bsonType: 'string' } },
      simulado: { bsonType: 'bool' }
    } } },
  validationLevel: 'strict', validationAction: 'error'
});
bd.calificaciones.createIndex({ 'agricultor.agricultor_id': 1, fecha: -1 }, { name: 'ix_agricultor_fecha' });
bd.calificaciones.createIndex({ 'producto.producto_id': 1 }, { name: 'ix_producto' });
bd.calificaciones.createIndex({ 'cliente.cliente_id': 1 }, { name: 'ix_cliente' });
bd.calificaciones.createIndex({ puntuacion: 1 }, { name: 'ix_puntuacion' });
bd.calificaciones.createIndex({ etiquetas: 1 }, { name: 'ix_etiquetas' });                  // multiclave

// ---------------------------------------------------------------------
// 3) incidencias: problemas detectados en entregas, recepciones y pagos
//    (origen: Oracle) con su historial de seguimiento incrustado.
// ---------------------------------------------------------------------
bd.createCollection('incidencias', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'tipo', 'severidad', 'origen', 'fecha', 'estado', 'historial'],
    properties: {
      _id: { bsonType: 'string', pattern: '^INC-[0-9]{6}$' },
      tipo: { enum: ['ENTREGA_NO_REALIZADA', 'ENTREGA_RECHAZADA', 'RECEPCION_OBSERVADA',
                     'RECEPCION_RECHAZADA', 'PAGO_RECHAZADO', 'PAGO_REEMBOLSADO', 'PAGO_ANULADO'] },
      severidad: { enum: ['BAJA', 'MEDIA', 'ALTA'] },
      origen: { bsonType: 'object', required: ['sistema', 'tabla', 'id'],
        properties: { sistema: { enum: ['oracle', 'postgresql'] },
                      tabla: { bsonType: 'string' }, id: entero } },
      referencias: { bsonType: 'object',
        properties: { pedido_id: entero, ruta_id: entero, centro_acopio_id: entero,
                      oferta_id: entero, monto: { bsonType: 'number' } } },
      fecha: { bsonType: 'date' },
      descripcion: { bsonType: ['string', 'null'] },
      estado: { enum: ['ABIERTA', 'EN_REVISION', 'RESUELTA'] },
      historial: { bsonType: 'array', minItems: 1,
        items: { bsonType: 'object', required: ['fecha', 'estado'],
          properties: { fecha: { bsonType: 'date' },
                        estado: { enum: ['REGISTRADA', 'EN_REVISION', 'RESUELTA'] },
                        nota: { bsonType: 'string' } } } }
    } } },
  validationLevel: 'strict', validationAction: 'error'
});
bd.incidencias.createIndex({ tipo: 1, fecha: -1 }, { name: 'ix_tipo_fecha' });
bd.incidencias.createIndex({ estado: 1, severidad: 1 }, { name: 'ix_estado_severidad' });
bd.incidencias.createIndex({ 'referencias.pedido_id': 1 }, { name: 'ix_ref_pedido' });
bd.incidencias.createIndex({ 'referencias.ruta_id': 1 }, { name: 'ix_ref_ruta' });
bd.incidencias.createIndex({ 'referencias.centro_acopio_id': 1 }, { name: 'ix_ref_centro' });

// ---------------------------------------------------------------------
// 4) perfil_agricultor: resumen de calidad por agricultor, calculado a
//    partir de "calificaciones" (se carga ya calculado). Evita recorrer
//    las 33 mil calificaciones cada vez que se quiere ver un ranking.
//    _id = agricultor_id de PostgreSQL.
// ---------------------------------------------------------------------
bd.createCollection('perfil_agricultor', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'nombre', 'total_calificaciones', 'puntuacion_promedio'],
    properties: {
      _id: entero, nombre: { bsonType: 'string' },
      total_calificaciones: { bsonType: ['int', 'long'], minimum: 0 },
      puntuacion_promedio: { bsonType: 'number', minimum: 1, maximum: 5 },
      promedio_aspectos: { bsonType: 'object' },
      productos: { bsonType: 'array',
        items: { bsonType: 'object', required: ['producto_id', 'promedio'],
          properties: { producto_id: entero, nombre: { bsonType: 'string' },
                        calificaciones: { bsonType: ['int', 'long'] }, promedio: { bsonType: 'number' } } } },
      ultima_calificacion: { bsonType: 'date' }
    } } },
  validationLevel: 'strict', validationAction: 'error'
});
bd.perfil_agricultor.createIndex({ puntuacion_promedio: -1 }, { name: 'ix_puntuacion_prom' });
bd.perfil_agricultor.createIndex({ total_calificaciones: -1 }, { name: 'ix_total' });

print('Colecciones creadas: ' + bd.getCollectionNames().join(', '));
