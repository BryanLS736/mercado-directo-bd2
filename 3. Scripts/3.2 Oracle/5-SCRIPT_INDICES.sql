/* ============================================================
   PROYECTO: MERCADO DIRECTO - ORACLE
   INDICES SELECCIONADOS PARA SUSTENTACION
   ============================================================
   Todos van sobre TS_MD_INDICES (ver archivo de configuracion
   inicial).
   ============================================================ */


/* ------------------------------------------------------------
   1. IDX_CAT_DETALLE_MAE
   Por que: no es "porque es FK". Es porque CAT_DETALLE es la
   tabla mas consultada de todo el modelo: cada INSERT/UPDATE de
   las tablas de negocio (lote, ruta_reparto, pago, etc.) resuelve
   primero un id de CAT_DETALLE filtrando por su catalogo
   (id_mae). Sin este indice, cada una de esas resoluciones hace
   un full scan de CAT_DETALLE.
   ------------------------------------------------------------ */
CREATE INDEX idx_cat_detalle_mae
    ON cat_detalle (id_mae)
    TABLESPACE TS_MD_INDICES;


/* ------------------------------------------------------------
   2. IDX_MOVIMIENTO_LOTE_FECHA
   Por que: FN_STOCK_ACTUAL_LOTE y cualquier "kardex" o historial
   de movimientos de un lote siempre filtran por lote_id y
   ordenan por fecha_movimiento. Este indice compuesto evita un
   escaneo completo de MOVIMIENTO_INVENTARIO cada vez que se
   calcula el stock de un lote, y de paso cubre la FK lote_id
   como columna lider. Al estar fisicamente ordenado por fecha
   dentro de cada lote, tambien evita el paso de ordenamiento
   (SORT ORDER BY) que exige la consulta.
   ------------------------------------------------------------ */
CREATE INDEX idx_movimiento_lote_fecha
    ON movimiento_inventario (lote_id, fecha_movimiento)
    LOCAL
    TABLESPACE TS_MD_INDICES;


/* ------------------------------------------------------------
   3. IDX_PAGO_PEDIDO
   Por que: pedido_id es una referencia INTERGESTOR (vive en
   PostgreSQL), asi que la aplicacion siempre busca los pagos de
   Oracle a partir de ese id (por ejemplo, dentro de
   FN_MONTO_TOTAL_PAGADO_PEDIDO). Sin indice, cada busqueda por
   pedido_id seria un full table scan sobre PAGO.
   ------------------------------------------------------------ */
CREATE INDEX idx_pago_pedido
    ON pago (pedido_id)
    TABLESPACE TS_MD_INDICES;


/* ------------------------------------------------------------
   4. IDX_LOTE_ESTADO
   Por que: antes de asignar un lote a una salida o a una nueva
   ruta, el sistema necesita listar rapido los lotes en estado
   DISPONIBLE. Con el tiempo, DISPONIBLE se vuelve una minoria
   frente al historico acumulado de lotes AGOTADOS, lo que le da
   buena selectividad real a este indice (no solo baja
   cardinalidad de valores).
   ------------------------------------------------------------ */
CREATE INDEX idx_lote_estado
    ON lote (estado_id)
    TABLESPACE TS_MD_INDICES;


/* ------------------------------------------------------------
   5. IDX_PAGO_ESTADO
   Por que: la conciliacion de pagos busca puntualmente los que
   quedaron PENDIENTE o RECHAZADO, que son minoria frente al
   historico acumulado de pagos APROBADO.
   ------------------------------------------------------------ */
CREATE INDEX idx_pago_estado
    ON pago (estado_id)
    TABLESPACE TS_MD_INDICES;