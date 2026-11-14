-- =====================================================================
-- 1_CREAR_KEYSPACE_Y_TABLAS.cql  -  Mercado Directo (Cassandra)
-- Crea el keyspace "mercado_cassandra" (replicación x3) y 5 tablas NUEVAS.
-- Estas tablas NO vienen de las colecciones de MongoDB: se construyen con
-- datos de PostgreSQL (pedidos) y Oracle (pagos, inventario, acopio), que son
-- datos de MUCHO VOLUMEN y ORDENADOS EN EL TIEMPO, el uso típico de Cassandra.
--
-- DISEÑO "QUERY FIRST": cada tabla responde a UNA pregunta de negocio y su
-- clave de partición es lo que siempre se filtra en esa consulta:
--
--   tabla                         origen        responde a
--   pedidos_por_cliente           PostgreSQL    historial de compras de un cliente
--   pagos_por_metodo_dia          Oracle        pagos de un método en un día
--   recaudacion_por_metodo_mes    Oracle        recaudación mensual por método de pago
--   movimientos_por_tipo_mes      Oracle        mermas/despachos/devoluciones por mes
--   recepciones_por_centro        Oracle        recepciones de cada centro de acopio por estado
--
-- Es normal repetir datos entre tablas (desnormalizar): se escribe más,
-- pero cada lectura va directo a una sola partición.
--
-- Ejecutar:  cqlsh -f 1_CREAR_KEYSPACE_Y_TABLAS.cql   (o desde DbGate)
-- =====================================================================
DROP KEYSPACE IF EXISTS mercado_cassandra;

CREATE KEYSPACE mercado_cassandra
  WITH replication = {'class': 'NetworkTopologyStrategy', 'datacenter1': 3}
  AND durable_writes = true;

USE mercado_cassandra;

-- 1. Historial de pedidos de un cliente (PostgreSQL: pedido + detalle_pedido)
CREATE TABLE pedidos_por_cliente (
  cliente_id               int,
  fecha_pedido             timestamp,
  pedido_id                int,
  fecha_entrega_solicitada date,
  costo_envio              double,
  subtotal                 double,
  kg                       double,
  n_detalles               int,
  total                    double,
  PRIMARY KEY ((cliente_id), fecha_pedido, pedido_id)
) WITH CLUSTERING ORDER BY (fecha_pedido DESC, pedido_id DESC);

-- 2. Pagos de un método en un día (Oracle: pago). Partición = método + día
--    para que ninguna partición crezca sin límite (técnica de "bucket" por día).
CREATE TABLE pagos_por_metodo_dia (
  metodo_pago        text,
  dia                date,
  fecha_pago         timestamp,
  pago_id            int,
  pedido_id          int,
  monto              double,
  estado_pago        text,
  codigo_transaccion text,
  observaciones      text,
  PRIMARY KEY ((metodo_pago, dia), fecha_pago, pago_id)
) WITH CLUSTERING ORDER BY (fecha_pago DESC, pago_id DESC);

-- 3. Recaudación mensual por método (solo pagos en estado PAGADO).
--    Tabla de totales ya calculados: CQL suma pero no tiene HAVING ni divisiones.
CREATE TABLE recaudacion_por_metodo_mes (
  metodo_pago text,
  mes         text,        -- 'AAAA-MM'
  total_pagos int,
  monto_total double,
  PRIMARY KEY ((metodo_pago), mes)
);

-- 4. Movimientos de inventario por tipo y mes (Oracle: movimiento_inventario)
CREATE TABLE movimientos_por_tipo_mes (
  tipo_movimiento  text,
  mes              text,   -- 'AAAA-MM'
  fecha_movimiento timestamp,
  movimiento_id    int,
  lote_id          int,
  codigo_lote      text,
  centro_acopio_id int,
  cantidad_kg      double,
  observaciones    text,
  PRIMARY KEY ((tipo_movimiento, mes), fecha_movimiento, movimiento_id)
) WITH CLUSTERING ORDER BY (fecha_movimiento DESC, movimiento_id DESC);

-- 5. Recepciones de cada centro de acopio (Oracle: recepcion_acopio).
--    El estado va como PRIMER clustering para poder agrupar por estado dentro del centro.
CREATE TABLE recepciones_por_centro (
  centro_acopio_id int,
  estado           text,
  fecha_recepcion  timestamp,
  recepcion_id     int,
  centro_nombre    text,
  codigo_recepcion text,
  oferta_id        int,
  observaciones    text,
  PRIMARY KEY ((centro_acopio_id), estado, fecha_recepcion, recepcion_id)
) WITH CLUSTERING ORDER BY (estado ASC, fecha_recepcion DESC, recepcion_id DESC);
