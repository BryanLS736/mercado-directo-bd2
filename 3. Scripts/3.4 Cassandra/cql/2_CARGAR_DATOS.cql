-- =====================================================================
-- 2_CARGAR_DATOS.cql  -  Mercado Directo (Cassandra)
-- Carga los archivos CSV de la carpeta datos/ con el comando COPY de cqlsh.
-- Rutas dentro del contenedor Docker: /proyecto/datos/...
-- Si no usan Docker, cambien /proyecto por la carpeta donde descomprimieron.
--   cqlsh -f 2_CARGAR_DATOS.cql
-- =====================================================================
USE mercado_cassandra;

COPY pedidos_por_cliente (cliente_id, fecha_pedido, pedido_id, fecha_entrega_solicitada, costo_envio, subtotal, kg, n_detalles, total)
  FROM '/proyecto/datos/pedidos_por_cliente.csv' WITH HEADER = true;

COPY pagos_por_metodo_dia (metodo_pago, dia, fecha_pago, pago_id, pedido_id, monto, estado_pago, codigo_transaccion, observaciones)
  FROM '/proyecto/datos/pagos_por_metodo_dia.csv' WITH HEADER = true;

COPY recaudacion_por_metodo_mes (metodo_pago, mes, total_pagos, monto_total)
  FROM '/proyecto/datos/recaudacion_por_metodo_mes.csv' WITH HEADER = true;

COPY movimientos_por_tipo_mes (tipo_movimiento, mes, fecha_movimiento, movimiento_id, lote_id, codigo_lote, centro_acopio_id, cantidad_kg, observaciones)
  FROM '/proyecto/datos/movimientos_por_tipo_mes.csv' WITH HEADER = true;

COPY recepciones_por_centro (centro_acopio_id, estado, fecha_recepcion, recepcion_id, centro_nombre, codigo_recepcion, oferta_id, observaciones)
  FROM '/proyecto/datos/recepciones_por_centro.csv' WITH HEADER = true;
