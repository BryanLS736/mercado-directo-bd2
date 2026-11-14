-- =====================================================================
-- 4_CONSULTAS_NEGOCIO.cql  -  Mercado Directo (Cassandra)
-- Consultas que responden preguntas de negocio. Cada una usa la tabla
-- diseñada para ella: se filtra por la CLAVE DE PARTICIÓN.
--   cqlsh --request-timeout=120 -f 4_CONSULTAS_NEGOCIO.cql
-- =====================================================================
USE mercado_cassandra;
CONSISTENCY QUORUM;      -- lee de la mayoría de réplicas (2 de 3)

-- C1. ¿Cómo han sido las últimas compras de un cliente y cuánto ha gastado? (cliente 4827)
SELECT pedido_id, fecha_pedido, kg, subtotal, costo_envio, total
FROM pedidos_por_cliente WHERE cliente_id = 4827 LIMIT 5;
SELECT COUNT(*) AS pedidos, SUM(kg) AS kg_total, SUM(total) AS gasto_total
FROM pedidos_por_cliente WHERE cliente_id = 4827;

-- C2. ¿Cuánto dinero se ha recaudado por cada método de pago? (solo pagos PAGADO)
SELECT metodo_pago, SUM(total_pagos) AS pagos, SUM(monto_total) AS recaudado
FROM recaudacion_por_metodo_mes GROUP BY metodo_pago;

-- C3. ¿Cómo se pagó el día de más movimiento (31/10/2026) con YAPE? Detalle y total del día
SELECT pago_id, pedido_id, fecha_pago, monto, estado_pago
FROM pagos_por_metodo_dia WHERE metodo_pago = 'YAPE' AND dia = '2026-10-31' LIMIT 5;
SELECT COUNT(*) AS pagos, SUM(monto) AS monto_total
FROM pagos_por_metodo_dia WHERE metodo_pago = 'YAPE' AND dia = '2026-10-31';

-- C4. ¿Cuántos kg se pierden por merma cada mes (y cómo se comparan con despachos y devoluciones)?
SELECT tipo_movimiento, mes, COUNT(*) AS movimientos, SUM(cantidad_kg) AS kg
FROM movimientos_por_tipo_mes GROUP BY tipo_movimiento, mes;

-- C5. ¿Qué centros de acopio tienen más recepciones observadas o rechazadas?
--     Se cuenta por centro y estado; el porcentaje se calcula al leer.
SELECT centro_acopio_id, estado, COUNT(*) AS recepciones
FROM recepciones_por_centro GROUP BY centro_acopio_id, estado;

-- C5b. Las últimas recepciones OBSERVADAS del centro con mayor tasa (centro 3, Barranca)
SELECT recepcion_id, codigo_recepcion, fecha_recepcion, observaciones
FROM recepciones_por_centro WHERE centro_acopio_id = 3 AND estado = 'OBSERVADA' LIMIT 5;

-- Una consulta que Cassandra RECHAZA (no filtra por la clave de partición):
-- SELECT * FROM pagos_por_metodo_dia WHERE monto > 1000;
--   -> "Cannot execute this query as it might involve data filtering"
--   Es el costo del diseño: hay que modelar las tablas según las consultas.
